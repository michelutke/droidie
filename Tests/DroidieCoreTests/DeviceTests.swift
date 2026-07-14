import XCTest
@testable import DroidieCore

final class DeviceTests: XCTestCase {
    func test_transport_usbSerial_isUsb() {
        let d = Device(serial: "39191FDJH0007Y", state: .device, model: "Pixel_8_Pro")
        XCTAssertEqual(d.transport, .usb)
    }

    func test_transport_ipSerial_isTcp() {
        let d = Device(serial: "192.168.1.42:5555", state: .device, model: nil)
        XCTAssertEqual(d.transport, .tcp)
    }

    func test_displayName_usesModelWithSpacesElseSerial() {
        XCTAssertEqual(Device(serial: "X", state: .device, model: "Pixel_8_Pro").displayName, "Pixel 8 Pro")
        XCTAssertEqual(Device(serial: "X", state: .device, model: nil).displayName, "X")
    }
}
