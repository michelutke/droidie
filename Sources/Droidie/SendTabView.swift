import SwiftUI
import UniformTypeIdentifiers
import DroidieCore

struct SendTabView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var transferQueue: TransferQueue
    @State private var dropActive = false
    @State private var autoClearTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(dropActive ? Color.accentColor : Color.secondary)
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc").font(.largeTitle)
                        Text("Drop files here")
                        Text("→ \(appState.settings.deviceDestPath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 120)
                .onDrop(of: [.fileURL], isTargeted: $dropActive) { providers in
                    handleDrop(providers)
                }

            List(transferQueue.jobs) { job in
                TransferRowView(job: job,
                                onCancel: { transferQueue.cancel(id: job.id) },
                                onRetry: { transferQueue.retry(id: job.id) })
            }
            .listStyle(.plain)
        }
        .padding(8)
        .onChange(of: transferQueue.jobs.map(\.status)) {
            scheduleAutoClear()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in _ = appState.pushToSelectedDevice([url]) }
            }
        }
        return !providers.isEmpty
    }

    private func scheduleAutoClear() {
        autoClearTask?.cancel()
        let allFinished = !transferQueue.jobs.isEmpty && transferQueue.jobs.allSatisfy {
            if case .done = $0.status { return true }
            if case .failed = $0.status { return false }  // keep failures visible
            return false
        }
        guard allFinished else { return }
        autoClearTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            transferQueue.clearFinished()
        }
    }
}

struct TransferRowView: View {
    let job: TransferJob
    let onCancel: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(job.displayName).lineLimit(1)
                if case .running(let percent) = job.status {
                    ProgressView(value: percent.map { Double($0) / 100 })
                        .progressViewStyle(.linear)
                }
                if case .failed(let message) = job.status {
                    Text(message).font(.caption).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer()
            if case .failed = job.status {
                Button { onRetry() } label: { Image(systemName: "arrow.clockwise.circle") }
                    .buttonStyle(.plain)
            }
            if isActive {
                Button { onCancel() } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.plain)
            }
        }
    }

    private var isActive: Bool {
        switch job.status {
        case .queued, .running: true
        default: false
        }
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.status {
        case .queued: Image(systemName: "clock").foregroundStyle(.secondary)
        case .running: Image(systemName: "arrow.up.circle").foregroundStyle(.blue)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }
}
