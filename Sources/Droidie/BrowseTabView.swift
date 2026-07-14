import SwiftUI
import UniformTypeIdentifiers
import DroidieCore

struct BrowseTabView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var deviceStore: DeviceStore
    @ObservedObject var transferQueue: TransferQueue

    @State private var path: String
    @State private var entries: [RemoteEntry] = []
    @State private var selection = Set<String>()
    @State private var loading = false
    @State private var errorText: String?
    @State private var dropActive = false
    @State private var loadGeneration = 0

    init(appState: AppState, deviceStore: DeviceStore, transferQueue: TransferQueue) {
        self.appState = appState
        self.deviceStore = deviceStore
        self.transferQueue = transferQueue
        _path = State(initialValue: appState.settings.deviceDestPath)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { navigateUp() } label: { Image(systemName: "chevron.up") }
                    .disabled(path == "/")
                Text(path).font(.caption).lineLimit(1).truncationMode(.head)
                Spacer()
                Button {
                    selection.removeAll()
                    Task { await load() }
                } label: { Image(systemName: "arrow.clockwise") }
            }

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            List(entries, selection: $selection) { entry in
                HStack {
                    Image(systemName: entry.isDirectory ? "folder" : "doc")
                    Text(entry.name).lineLimit(1)
                    Spacer()
                    if !entry.isDirectory {
                        Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    if entry.isDirectory {
                        path = RemotePath.join(path, entry.name)
                        selection.removeAll()
                        Task { await load() }
                    }
                }
            }
            .listStyle(.plain)
            .overlay { if loading { ProgressView() } }
            .onDrop(of: [.fileURL], isTargeted: $dropActive) { providers in
                handleDrop(providers)
            }

            Button("Save \(selection.count) to Mac") { pullSelected() }
                .disabled(selection.isEmpty || deviceStore.selectedDevice == nil)
        }
        .padding(8)
        .task { await load() }
        .onChange(of: deviceStore.selectedSerial) { _, _ in
            selection.removeAll()
            path = appState.settings.deviceDestPath
            Task { await load() }
        }
    }

    private func navigateUp() {
        path = (path as NSString).deletingLastPathComponent
        if path.isEmpty { path = "/" }
        selection.removeAll()
        Task { await load() }
    }

    private func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        guard let runner = appState.runner, let serial = deviceStore.selectedDevice?.serial else {
            guard generation == loadGeneration else { return }
            entries = []
            return
        }
        loading = true
        errorText = nil
        defer { loading = false }
        do {
            let result = try await runner.run(["-s", serial, "shell", "ls", "-la", RemotePath.quoted(path)],
                                              onOutput: nil)
            guard generation == loadGeneration else { return }
            if result.exitCode == 0 {
                entries = LsParser.parse(result.stdout)
            } else {
                errorText = result.stderr.isEmpty ? result.stdout : result.stderr
            }
        } catch {
            guard generation == loadGeneration else { return }
            errorText = error.localizedDescription
        }
    }

    private func pullSelected() {
        guard let serial = deviceStore.selectedDevice?.serial else { return }
        let remotePaths = selection.map { RemotePath.join(path, $0) }
        transferQueue.enqueuePull(remotePaths: remotePaths,
                                  localDir: URL(fileURLWithPath: appState.settings.macDownloadDir),
                                  serial: serial)
        selection.removeAll()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let serial = deviceStore.selectedDevice?.serial else { return false }
        let targetDir = path
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    appState.transferQueue?.enqueuePush(files: [url], remoteDir: targetDir, serial: serial)
                }
            }
        }
        return !providers.isEmpty
    }
}
