import XCTest
@testable import DroidieCore

final class TrackDevicesParserTests: XCTestCase {
    func test_parse_usbAndWifiDevices() {
        let payload = """
        39191FDJH0007Y         device product:husky model:Pixel_8_Pro device:husky transport_id:1
        192.168.1.42:40913     device product:husky model:Pixel_8_Pro device:husky transport_id:2
        """
        let devices = TrackDevicesParser.parse(payload)
        XCTAssertEqual(devices.count, 2)
        XCTAssertEqual(devices[0], Device(serial: "39191FDJH0007Y", state: .device, model: "Pixel_8_Pro"))
        XCTAssertEqual(devices[1].transport, .tcp)
    }

    func test_parse_unauthorizedDevice_noModel() {
        let devices = TrackDevicesParser.parse("39191FDJH0007Y  unauthorized transport_id:1")
        XCTAssertEqual(devices, [Device(serial: "39191FDJH0007Y", state: .unauthorized, model: nil)])
    }

    func test_parse_emptyPayload_returnsEmpty() {
        XCTAssertEqual(TrackDevicesParser.parse(""), [])
        XCTAssertEqual(TrackDevicesParser.parse("\n"), [])
    }

    func test_parse_unknownState_mapsToUnknown() {
        XCTAssertEqual(TrackDevicesParser.parse("SER connecting")[0].state, .unknown)
    }
}
