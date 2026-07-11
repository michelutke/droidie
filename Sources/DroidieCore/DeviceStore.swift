import Foundation

/// Owns device discovery state: current device list, selection, reconnect, and pairing.
@MainActor
public final class DeviceStore: ObservableObject {
    /// Currently known devices from the last tracker snapshot.
    @Published public private(set) var devices: [Device] = []
    /// Serial of the currently selected device, if any.
    @Published public var selectedSerial: String?

    private let tracker: DeviceTracker
    private let runner: AdbRunning
    private let settings: AppSettings

    /// Creates a store wired to the given tracker, adb runner, and settings.
    public init(tracker: DeviceTracker, runner: AdbRunning, settings: AppSettings) {
        self.tracker = tracker
        self.runner = runner
        self.settings = settings
    }

    /// The currently selected device, if it is present in the current device list.
    public var selectedDevice: Device? {
        devices.first { $0.serial == selectedSerial }
    }

    /// Starts tracking devices, restarting the tracker (with adb start-server + backoff) on disconnect.
    public func start() {
        tracker.onDevices = { [weak self] devices in
            Task { @MainActor in self?.apply(devices: devices) }
        }
        tracker.onDisconnect = { [weak self] in
            Task { @MainActor in await self?.restartTracking() }
        }
        tracker.start()
    }

    /// Updates the device list and auto-selects the first `.device`-state device if the current selection is gone.
    public func apply(devices: [Device]) {
        self.devices = devices
        if selectedSerial == nil || !devices.contains(where: { $0.serial == selectedSerial }) {
            selectedSerial = devices.first { $0.state == .device }?.serial
        }
    }

    /// Remembered WiFi endpoints that are not currently connected.
    public func offlineRememberedEndpoints() -> [String] {
        let connected = Set(devices.map(\.serial))
        return settings.rememberedWifiEndpoints.filter { !connected.contains($0) }
    }

    /// Runs `adb connect` against the given endpoint.
    public func reconnect(endpoint: String) async {
        _ = try? await runner.run(["connect", endpoint], onOutput: nil)
    }

    /// Pairs with the given pairing endpoint/code, then connects, remembering the endpoint on success; returns nil on success or an error string.
    public func pair(pairingEndpoint: String, code: String, connectEndpoint: String) async -> String? {
        do {
            let pairResult = try await runner.run(["pair", pairingEndpoint, code], onOutput: nil)
            guard pairResult.exitCode == 0, !pairResult.stdout.lowercased().contains("failed") else {
                return pairResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let connectResult = try await runner.run(["connect", connectEndpoint], onOutput: nil)
            guard connectResult.exitCode == 0, !connectResult.stdout.lowercased().contains("failed") else {
                return connectResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            settings.rememberWifiEndpoint(connectEndpoint)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// Restarts adb server and re-establishes device tracking after a 2s backoff.
    private func restartTracking() async {
        _ = try? await runner.run(["start-server"], onOutput: nil)
        try? await Task.sleep(for: .seconds(2))
        tracker.start()
    }
}
