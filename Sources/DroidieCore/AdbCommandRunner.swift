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

        let stdoutCollector = Collector()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            stdoutCollector.append(text)
            onOutput?(text)
        }

        let stderrCollector = Collector()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            stderrCollector.append(text)
        }

        let launchState = LaunchState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { proc in
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: AdbResult(
                        exitCode: proc.terminationStatus,
                        stdout: stdoutCollector.joined(),
                        stderr: stderrCollector.joined()
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
