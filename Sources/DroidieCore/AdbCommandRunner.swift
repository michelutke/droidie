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

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { proc in
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: AdbResult(
                        exitCode: proc.terminationStatus,
                        stdout: stdoutCollector.joined(),
                        stderr: String(data: errData, encoding: .utf8) ?? ""
                    ))
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
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
