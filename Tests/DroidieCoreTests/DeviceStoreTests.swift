import XCTest
@testable import DroidieCore

@MainActor
final class DeviceStoreTests: XCTestCase {
    private func makeStore(runner: FakeRunner = FakeRunner()) -> DeviceStore {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "droidie-test-\(UUID().uuidString)")!)
        settings.rememberWifiEndpoint("192.168.1.42:5555")
        return DeviceStore(tracker: DeviceTracker(port: 1), runner: runner, settings: settings)
    }

    func test_apply_autoSelectsFirstReadyDevice() {
        let store = makeStore()
        store.apply(devices: [
            Device(serial: "A", state: .unauthorized, model: nil),
            Device(serial: "B", state: .device, model: "Pixel_8_Pro"),
        ])
        XCTAssertEqual(store.selectedSerial, "B")
    }

    func test_apply_unauthorizedOnlyDevice_isSelectedAsFallback() {
        let store = makeStore()
        store.apply(devices: [Device(serial: "A", state: .unauthorized, model: nil)])
        XCTAssertEqual(store.selectedSerial, "A")
    }

    func test_apply_keepsSelectionIfStillPresent() {
        let store = makeStore()
        store.apply(devices: [Device(serial: "A", state: .device, model: nil),
                              Device(serial: "B", state: .device, model: nil)])
        store.selectedSerial = "B"
        store.apply(devices: [Device(serial: "B", state: .device, model: nil)])
        XCTAssertEqual(store.selectedSerial, "B")
    }

    func test_offlineRememberedEndpoints_excludesConnected() {
        let store = makeStore()
        store.apply(devices: [Device(serial: "192.168.1.42:5555", state: .device, model: nil)])
        XCTAssertEqual(store.offlineRememberedEndpoints(), [])
        store.apply(devices: [])
        XCTAssertEqual(store.offlineRememberedEndpoints(), ["192.168.1.42:5555"])
    }

    func test_reconnect_runsAdbConnect() async {
        let runner = FakeRunner()
        let store = makeStore(runner: runner)
        await store.reconnect(endpoint: "192.168.1.42:5555")
        XCTAssertEqual(runner.calls.first, ["connect", "192.168.1.42:5555"])
    }

    func test_pair_success_runsPairThenConnect_andRemembers() async {
        let runner = FakeRunner()
        runner.results = [
            AdbResult(exitCode: 0, stdout: "Successfully paired to 192.168.1.42:37123", stderr: ""),
            AdbResult(exitCode: 0, stdout: "connected to 192.168.1.42:5555", stderr: ""),
        ]
        let store = makeStore(runner: runner)
        let error = await store.pair(pairingEndpoint: "192.168.1.42:37123", code: "123456",
                                     connectEndpoint: "192.168.1.42:5555")
        XCTAssertNil(error)
        XCTAssertEqual(runner.calls, [["pair", "192.168.1.42:37123", "123456"],
                                      ["connect", "192.168.1.42:5555"]])
    }

    func test_pair_failure_returnsErrorText() async {
        let runner = FakeRunner()
        runner.results = [AdbResult(exitCode: 1, stdout: "Failed: Wrong password", stderr: "")]
        let store = makeStore(runner: runner)
        let error = await store.pair(pairingEndpoint: "192.168.1.42:37123", code: "000000",
                                     connectEndpoint: "192.168.1.42:5555")
        XCTAssertNotNil(error)
    }
}
