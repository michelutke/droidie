import Foundation
import DroidieCore

@MainActor
final class AppState: ObservableObject {
    let settings: AppSettings
    let adbPath: String?
    let runner: AdbRunning?
    let deviceStore: DeviceStore?
    let transferQueue: TransferQueue?

    init(settings: AppSettings, adbPath: String?) {
        self.settings = settings
        self.adbPath = adbPath
        if let adbPath {
            let runner = AdbCommandRunner(adbPath: adbPath)
            self.runner = runner
            self.deviceStore = DeviceStore(tracker: DeviceTracker(), runner: runner, settings: settings)
            self.transferQueue = TransferQueue(runner: runner)
        } else {
            self.runner = nil
            self.deviceStore = nil
            self.transferQueue = nil
        }
    }

    static func bootstrap() -> AppState {
        let settings = AppSettings()
        let path = AdbPathResolver(override: settings.adbPathOverride).resolve()
        return AppState(settings: settings, adbPath: path)
    }

    func startServices() {
        guard let runner, let deviceStore else { return }
        Task {
            _ = try? await runner.run(["start-server"], onOutput: nil)
            deviceStore.start()
        }
    }

    @discardableResult
    func pushToSelectedDevice(_ urls: [URL]) -> Bool {
        guard let deviceStore, let transferQueue,
              let serial = deviceStore.selectedDevice?.serial else { return false }
        transferQueue.enqueuePush(files: urls, remoteDir: settings.deviceDestPath, serial: serial)
        return true
    }
}
