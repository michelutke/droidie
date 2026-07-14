import Foundation

/// Lifecycle state of a transfer job.
public enum TransferStatus: Equatable, Sendable {
    /// Waiting to be processed.
    case queued
    /// Actively transferring, with an optional progress percent.
    case running(Int?)
    /// Completed successfully.
    case done
    /// Failed with an error message.
    case failed(String)
}

/// A single push or pull transfer job tracked by `TransferQueue`.
public struct TransferJob: Identifiable, Sendable {
    /// Unique identifier for this job.
    public let id: UUID
    /// Device serial this job runs against.
    public let serial: String
    /// Human-readable name shown in the UI.
    public let displayName: String
    /// Current lifecycle state.
    public var status: TransferStatus

    /// Distinguishes a push (local -> device) from a pull (device -> local) job.
    enum Kind: Sendable {
        case push(local: URL, remoteDir: String)
        case pull(remotePath: String, localDir: URL)
    }
    let kind: Kind

    init(serial: String, displayName: String, kind: Kind) {
        self.id = UUID()
        self.serial = serial
        self.displayName = displayName
        self.kind = kind
        self.status = .queued
    }
}

/// Serial FIFO queue of adb push/pull jobs with progress tracking and media-scan broadcast.
@MainActor
public final class TransferQueue: ObservableObject {
    /// All jobs, in FIFO order.
    @Published public private(set) var jobs: [TransferJob] = []

    private let runner: AdbRunning
    private var isProcessing = false
    private var runningTask: (id: UUID, task: Task<Void, Never>)?

    /// Creates a queue that dispatches adb commands through the given runner.
    public init(runner: AdbRunning) {
        self.runner = runner
    }

    /// Progress percent of the currently running job, or nil when idle.
    public var overallPercent: Int? {
        for job in jobs {
            if case .running(let p) = job.status { return p }
        }
        return nil
    }

    /// Enqueues a push job for each file, then starts processing if idle.
    public func enqueuePush(files: [URL], remoteDir: String, serial: String) {
        for file in files {
            jobs.append(TransferJob(serial: serial, displayName: file.lastPathComponent,
                                    kind: .push(local: file, remoteDir: remoteDir)))
        }
        processNext()
    }

    /// Enqueues a pull job for each remote path, then starts processing if idle.
    public func enqueuePull(remotePaths: [String], localDir: URL, serial: String) {
        for remote in remotePaths {
            let name = remote.split(separator: "/").last.map(String.init) ?? remote
            jobs.append(TransferJob(serial: serial, displayName: name,
                                    kind: .pull(remotePath: remote, localDir: localDir)))
        }
        processNext()
    }

    /// Cancels a job: removes it if still queued, or terminates it if currently running.
    public func cancel(id: UUID) {
        if let running = runningTask, running.id == id {
            running.task.cancel()
        } else {
            jobs.removeAll { $0.id == id && $0.status == .queued }
        }
    }

    /// Requeues a failed job so it is reprocessed.
    public func retry(id: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == id }),
              case .failed = jobs[index].status else { return }
        jobs[index].status = .queued
        processNext()
    }

    /// Removes all jobs that finished, successfully or not.
    public func clearFinished() {
        jobs.removeAll {
            if case .done = $0.status { return true }
            if case .failed = $0.status { return true }
            return false
        }
    }

    private func processNext() {
        guard !isProcessing else { return }
        guard let index = jobs.firstIndex(where: { $0.status == .queued }) else { return }
        isProcessing = true
        let job = jobs[index]
        jobs[index].status = .running(nil)

        let task = Task { [weak self] in
            await self?.execute(job)
            await MainActor.run {
                guard let self else { return }
                self.runningTask = nil
                self.isProcessing = false
                self.processNext()
            }
        }
        runningTask = (job.id, task)
    }

    private func execute(_ job: TransferJob) async {
        let args: [String]
        switch job.kind {
        case .push(let local, let remoteDir):
            args = ["-s", job.serial, "push", local.path, remoteDir]
        case .pull(let remotePath, let localDir):
            args = ["-s", job.serial, "pull", remotePath, localDir.path]
        }

        do {
            let jobID = job.id
            let result = try await runner.run(args) { [weak self] chunk in
                guard let percent = ProgressParser.percent(in: chunk) else { return }
                Task { @MainActor in
                    self?.setStatus(jobID, .running(percent))
                }
            }
            if Task.isCancelled {
                setStatus(job.id, .failed("cancelled"))
            } else if result.exitCode == 0 {
                setStatus(job.id, .done)
                await mediaScanIfNeeded(job)
            } else {
                let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                setStatus(job.id, .failed(message.isEmpty ? result.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : message))
            }
        } catch {
            setStatus(job.id, .failed(error.localizedDescription))
        }
    }

    /// Indexes the pushed file in MediaStore so it appears immediately in Files/Gallery apps.
    /// Uses the MediaStore scan_file content call — `cmd media scan` and the scanner
    /// broadcast are both gone on Android 14+. Runs for every file type: non-media files
    /// are invisible in MediaStore-backed views (e.g. Files "Downloads") until indexed.
    private func mediaScanIfNeeded(_ job: TransferJob) async {
        guard case .push(let local, let remoteDir) = job.kind else { return }
        let remoteFile = RemotePath.join(remoteDir, local.lastPathComponent)
        _ = try? await runner.run(["-s", job.serial, "shell", "content", "call",
                                   "--uri", "content://media/", "--method", "scan_file",
                                   "--arg", RemotePath.quoted(remoteFile)],
                                  onOutput: nil)
    }

    private func setStatus(_ id: UUID, _ status: TransferStatus) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        // don't overwrite a terminal status with progress updates
        if case .running = jobs[index].status {
            jobs[index].status = status
        } else if case .running = status {
            return
        } else {
            jobs[index].status = status
        }
    }
}
