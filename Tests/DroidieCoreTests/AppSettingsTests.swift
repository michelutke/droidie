import XCTest
@testable import DroidieCore

final class AppSettingsTests: XCTestCase {
    private func freshSettings() -> AppSettings {
        let suite = "droidie-test-\(UUID().uuidString)"
        return AppSettings(defaults: UserDefaults(suiteName: suite)!)
    }

    func test_defaults() {
        let s = freshSettings()
        XCTAssertEqual(s.deviceDestPath, "/storage/emulated/0/Download")
        XCTAssertEqual(s.macDownloadDir, NSString("~/Downloads").expandingTildeInPath)
        XCTAssertNil(s.adbPathOverride)
        XCTAssertEqual(s.rememberedWifiEndpoints, [])
    }

    func test_valuesPersist() {
        let s = freshSettings()
        s.deviceDestPath = "/sdcard/DCIM"
        s.adbPathOverride = "/x/adb"
        XCTAssertEqual(s.deviceDestPath, "/sdcard/DCIM")
        XCTAssertEqual(s.adbPathOverride, "/x/adb")
    }

    func test_emptyStringPersisted_getterFallsBackToDefault() {
        let s = freshSettings()
        s.deviceDestPath = ""
        XCTAssertEqual(s.deviceDestPath, "/storage/emulated/0/Download")
        s.macDownloadDir = "   "
        XCTAssertEqual(s.macDownloadDir, NSString("~/Downloads").expandingTildeInPath)
        s.adbPathOverride = ""
        XCTAssertNil(s.adbPathOverride)
    }

    func test_rememberWifiEndpoint_dedupsMostRecentFirst() {
        let s = freshSettings()
        s.rememberWifiEndpoint("192.168.1.42:5555")
        s.rememberWifiEndpoint("192.168.1.99:5555")
        s.rememberWifiEndpoint("192.168.1.42:5555")
        XCTAssertEqual(s.rememberedWifiEndpoints, ["192.168.1.42:5555", "192.168.1.99:5555"])
    }
}
