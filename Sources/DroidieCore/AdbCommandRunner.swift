import Foundation

/// Result of running an adb command: exit code plus captured stdout/stderr.
public struct AdbResult: Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    /// Creates an AdbResult.
    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

/// Abstraction over running adb commands, allowing fakes in tests of dependent code.
public protocol AdbRunning: Sendable {
    /// Runs adb with the given arguments, streaming stdout chunks to onOutput as they arrive.
    @discardableResult
    func run(_ args: [String], onOutput: (@Sendable (String) -> Void)?) async throws -> AdbResult

    /// Runs adb with the given arguments, discarding all output. Use this for commands like
    /// `start-server` that may fork a long-lived daemon inheriting the pipe write-ends —
    /// capturing output for those can hang forever waiting for EOF that never comes.
    func runDiscardingOutput(_ args: [String]) async throws -> Int32
}

extension AdbRunning {
    /// Default implementation for fakes: just discards the result of `run`. Real usage
    /// (`AdbCommandRunner`) overrides this with a pipe-free implementation.
    public func runDiscardingOutput(_ args: [String]) async throws -> Int32 {
        try await run(args, onOutput: nil).exitCode
    }
}

/// Runs adb as a subprocess, streaming stdout and supporting cooperative cancellation.
public final class AdbCommandRunner: AdbRunning {
    private let adbPath: String

    /// Creates a runner that invokes the adb executable at the given path.
    public init(adbPath: String) {
        self.adbPath = adbPath
    }

    /// Runs adb with the given arguments, streaming stdout chunks to onOutput as they arrive.
    @discardableResult
    public func run(_ args: [String], onOutput: (@Sendable (String) -> Void)? = nil) async throws -> AdbResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let stdoutCollector = DataCollector()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stdoutCollector.append(data)
            // Best-effort decode of this chunk for progress callbacks; a failed decode
            // (e.g. a multi-byte UTF-8 character split across chunk boundaries) just
            // skips the callback for this chunk — the raw bytes are still retained in
            // stdoutCollector and decoded in full once the process finishes.
            if let text = String(data: data, encoding: .utf8) {
                onOutput?(text)
            }
        }

        let stderrCollector = DataCollector()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            stderrCollector.append(data)
        }

        let launchState = LaunchState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { proc in
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    // The readabilityHandler gives no guarantee that the final buffered
                    // pipe data was delivered before the process exits, so drain any
                    // remainder directly from the file handles.
                    if let remainder = try? outPipe.fileHandleForReading.readToEnd(), !remainder.isEmpty {
                        stdoutCollector.append(remainder)
                    }
                    if let remainder = try? errPipe.fileHandleForReading.readToEnd(), !remainder.isEmpty {
                        stderrCollector.append(remainder)
                    }
                    continuation.resume(returning: AdbResult(
                        exitCode: proc.terminationStatus,
                        stdout: stdoutCollector.decodedString(),
                        stderr: stderrCollector.decodedString()
                    ))
                }
                guard launchState.beginLaunch() else {
                    process.terminationHandler = nil
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    try process.run()
                    launchState.endLaunch(process)
                } catch {
                    process.terminationHandler = nil
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            launchState.cancel(process)
        }
    }

    /// Runs adb with no pipes at all (output goes to /dev/null), so a forked daemon that
    /// inherits the write-ends (e.g. `adb start-server`) can never cause a hang waiting for
    /// EOF on a pipe nothing will ever close. The continuation is resumed purely from the
    /// terminationHandler.
    public func runDiscardingOutput(_ args: [String]) async throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: adbPath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        let launchState = LaunchState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { proc in
                    continuation.resume(returning: proc.terminationStatus)
                }
                guard launchState.beginLaunch() else {
                    process.terminationHandler = nil
                    continuation.resume(throwing: CancellationError())
                    return
                }
                do {
                    try process.run()
                    launchState.endLaunch(process)
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            launchState.cancel(process)
        }
    }
}

/// Tracks process launch state so cancellation never races `Process.run()`.
private final class LaunchState: @unchecked Sendable {
    private enum State {
        case notStarted
        case launched
        case cancelled
    }

    private let lock = NSLock()
    private var state: State = .notStarted

    /// Called just before invoking `process.run()`. Returns false if cancellation
    /// already happened, meaning the caller must not launch the process.
    func beginLaunch() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return state != .cancelled
    }

    /// Called immediately after a successful `process.run()`. If cancellation
    /// raced in while the process was launching, terminates it now.
    func endLaunch(_ process: Process) {
        lock.lock()
        let wasCancelled = state == .cancelled
        if !wasCancelled { state = .launched }
        lock.unlock()
        if wasCancelled { process.terminate() }
    }

    /// Called from the cancellation handler. Terminates immediately if the
    /// process is already launched; otherwise records the cancellation so
    /// `beginLaunch()`/`endLaunch()` can react appropriately.
    func cancel(_ process: Process) {
        lock.lock()
        let wasLaunched = state == .launched
        state = .cancelled
        lock.unlock()
        if wasLaunched { process.terminate() }
    }
}

/// Thread-safe string collector for streamed chunks.
final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var chunks: [String] = []

    /// Appends a chunk to the collection.
    func append(_ s: String) { lock.lock(); chunks.append(s); lock.unlock() }

    /// Returns all collected chunks joined into one string.
    func joined() -> String { lock.lock(); defer { lock.unlock() }; return chunks.joined() }
}

/// Thread-safe raw byte collector for streamed pipe data. Collecting raw bytes rather
/// than pre-decoded strings avoids dropping a chunk whose boundary splits a multi-byte
/// UTF-8 character.
final class DataCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    /// Appends a chunk of raw bytes to the collection.
    func append(_ chunk: Data) { lock.lock(); data.append(chunk); lock.unlock() }

    /// Decodes all collected bytes as UTF-8, falling back to a lossy decode if the
    /// full byte stream isn't valid UTF-8.
    func decodedString() -> String {
        lock.lock(); let snapshot = data; lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? String(decoding: snapshot, as: UTF8.self)
    }
}
