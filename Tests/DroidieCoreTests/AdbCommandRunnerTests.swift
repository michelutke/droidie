import XCTest
@testable import DroidieCore

final class AdbCommandRunnerTests: XCTestCase {
    /// Writes an executable shell script to a temp dir and returns its path.
    private func makeFakeAdb(_ script: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("droidie-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("adb").path
        try ("#!/bin/bash\n" + script).write(toFile: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
        return path
    }

    func test_run_capturesStdoutStderrAndExitCode() async throws {
        let adb = try makeFakeAdb("echo out-line; echo err-line >&2; exit 3")
        let result = try await AdbCommandRunner(adbPath: adb).run(["push"], onOutput: nil)
        XCTAssertEqual(result.exitCode, 3)
        XCTAssertTrue(result.stdout.contains("out-line"))
        XCTAssertTrue(result.stderr.contains("err-line"))
    }

    func test_run_streamsOutputChunks() async throws {
        let adb = try makeFakeAdb("printf '[ 10%%] f\\r'; printf '[100%%] f\\n'")
        let collected = Collector()
        _ = try await AdbCommandRunner(adbPath: adb).run(["push"]) { chunk in
            collected.append(chunk)
        }
        XCTAssertEqual(ProgressParser.percent(in: collected.joined()), 100)
    }

    func test_run_receivesArguments() async throws {
        let adb = try makeFakeAdb(#"echo "$@""#)
        let result = try await AdbCommandRunner(adbPath: adb).run(["-s", "SER", "shell", "ls"], onOutput: nil)
        XCTAssertTrue(result.stdout.contains("-s SER shell ls"))
    }

    func test_run_cancellation_terminatesProcess() async throws {
        let adb = try makeFakeAdb("sleep 30")
        let start = Date()
        let task = Task { try await AdbCommandRunner(adbPath: adb).run(["push"], onOutput: nil) }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        _ = try? await task.value
        XCTAssertLessThan(Date().timeIntervalSince(start), 5)
    }

    func test_run_largeStderr_doesNotHang() async throws {
        let adb = try makeFakeAdb("head -c 131072 /dev/zero | tr '\\0' 'e' >&2; exit 0")
        let result = try await AdbCommandRunner(adbPath: adb).run(["push"], onOutput: nil)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertGreaterThanOrEqual(result.stderr.count, 131_072)
    }

    func test_run_multiByteCharacterAcrossChunkBoundary_isPreserved() async throws {
        let adb = try makeFakeAdb(
            "printf 'a%.0s' $(seq 1 100000); printf '\\303\\274'; printf 'b%.0s' $(seq 1 100000)"
        )
        let result = try await AdbCommandRunner(adbPath: adb).run(["push"], onOutput: nil)
        XCTAssertTrue(result.stdout.contains("ü"))
        XCTAssertEqual(result.stdout.unicodeScalars.count, 200_001)
    }

    func test_run_preCancelledTask_doesNotCrash() async throws {
        let adb = try makeFakeAdb("sleep 5")
        let task = Task {
            try await AdbCommandRunner(adbPath: adb).run(["push"], onOutput: nil)
        }
        task.cancel()
        do {
            _ = try await task.value
        } catch is CancellationError {
            // Expected outcome: cancelled before or during launch.
        } catch {
            // Also acceptable: process launched and was terminated, surfacing a non-zero exit.
        }
    }
}
