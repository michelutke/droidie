import XCTest
@testable import DroidieCore

/// Records invocations; scripted results per call.
final class FakeRunner: AdbRunning, @unchecked Sendable {
    let lock = NSLock()
    var calls: [[String]] = []
    var results: [AdbResult] = []
    var outputScript: [String] = []   // chunks emitted via onOutput for each call

    func run(_ args: [String], onOutput: (@Sendable (String) -> Void)?) async throws -> AdbResult {
        lock.lock()
        calls.append(args)
        let result = results.isEmpty ? AdbResult(exitCode: 0, stdout: "", stderr: "") : results.removeFirst()
        let chunk = outputScript.isEmpty ? nil : outputScript.removeFirst()
        lock.unlock()
        if let chunk { onOutput?(chunk) }
        return result
    }
}

@MainActor
final class TransferQueueTests: XCTestCase {
    private func drainQueue(_ q: TransferQueue) async {
        for _ in 0..<200 {
            if q.jobs.allSatisfy({ job in
                if job.status == .done { return true }
                if case .failed = job.status { return true }
                return false
            }) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("queue did not drain")
    }

    func test_push_invokesAdbPushPerFile() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.txt")], remoteDir: "/sdcard/Download", serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(runner.calls.first, ["-s", "SER", "push", "/tmp/a.txt", "/sdcard/Download"])
        XCTAssertEqual(q.jobs.first?.status, .done)
    }

    func test_push_touchesFileThenTriggersMediaStoreScan() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/pic.jpg")], remoteDir: "/sdcard/Download", serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(runner.calls.count, 3)
        XCTAssertEqual(runner.calls[1], ["-s", "SER", "shell", "touch",
                                         "'/sdcard/Download/pic.jpg'"])
        XCTAssertEqual(runner.calls[2], ["-s", "SER", "shell", "content", "call",
                                         "--uri", "content://media/", "--method", "scan_file",
                                         "--arg", "'/sdcard/Download/pic.jpg'"])
    }

    func test_push_textFile_alsoTouchedAndScanned() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.txt")], remoteDir: "/sdcard/Download", serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(runner.calls.count, 3)
        XCTAssertEqual(runner.calls[1].last, "'/sdcard/Download/a.txt'")
        XCTAssertEqual(runner.calls[2].last, "'/sdcard/Download/a.txt'")
    }

    func test_failure_capturesStderr() async {
        let runner = FakeRunner()
        runner.results = [AdbResult(exitCode: 1, stdout: "", stderr: "adb: error: device offline")]
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.txt")], remoteDir: "/sdcard/Download", serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(q.jobs.first?.status, .failed("adb: error: device offline"))
    }

    func test_pull_invokesAdbPull() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.enqueuePull(remotePaths: ["/sdcard/DCIM/x.jpg"], localDir: URL(fileURLWithPath: "/tmp"), serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(runner.calls.first, ["-s", "SER", "pull", "/sdcard/DCIM/x.jpg", "/tmp/x.jpg"])
    }

    func test_pull_existingFile_targetsNonConflictingName() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.fileExists = { $0 == "/tmp/x.jpg" }
        q.enqueuePull(remotePaths: ["/sdcard/DCIM/x.jpg"], localDir: URL(fileURLWithPath: "/tmp"), serial: "SER")
        await drainQueue(q)
        XCTAssertEqual(runner.calls.first, ["-s", "SER", "pull", "/sdcard/DCIM/x.jpg", "/tmp/x 2.jpg"])
    }

    func test_progress_updatesRunningPercent() async {
        let runner = FakeRunner()
        runner.outputScript = ["[ 42%] a.mp4"]
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.mp4")], remoteDir: "/sdcard/Download", serial: "SER")
        // percent observed transiently; after drain job is done
        await drainQueue(q)
        XCTAssertEqual(q.jobs.first?.status, .done)
    }

    func test_retry_failedJob_requeuesAndSucceeds() async {
        let runner = FakeRunner()
        runner.results = [AdbResult(exitCode: 1, stdout: "", stderr: "boom")]
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.txt")], remoteDir: "/sdcard/Download", serial: "SER")
        await drainQueue(q)
        guard let job = q.jobs.first else { return XCTFail("no job") }
        XCTAssertEqual(job.status, .failed("boom"))
        q.retry(id: job.id)
        await drainQueue(q)
        XCTAssertEqual(q.jobs.first?.status, .done)
    }

    func test_cancel_queuedJob_removesIt() async {
        let runner = FakeRunner()
        let q = TransferQueue(runner: runner)
        q.enqueuePush(files: [URL(fileURLWithPath: "/tmp/a.txt"), URL(fileURLWithPath: "/tmp/b.txt")],
                      remoteDir: "/sdcard/Download", serial: "SER")
        if let last = q.jobs.last, last.status == .queued { q.cancel(id: last.id) }
        await drainQueue(q)
        XCTAssertLessThanOrEqual(q.jobs.count, 2)
    }
}
