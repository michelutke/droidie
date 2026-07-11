import XCTest
import Network
import Darwin
@testable import DroidieCore

final class DeviceTrackerTests: XCTestCase {
    /// Binds an ephemeral port then immediately releases it, guaranteeing nothing is
    /// listening — connecting to it yields a real "connection refused".
    private func closedPort() -> UInt16 {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        addr.sin_port = 0
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                _ = Darwin.bind(fd, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        var actual = sockaddr_in()
        var actualLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &actual) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                _ = getsockname(fd, saPtr, &actualLen)
            }
        }
        close(fd)
        return UInt16(bigEndian: actual.sin_port)
    }

    /// Minimal fake adb server: accepts one connection, reads the request,
    /// replies OKAY + one framed device-list payload.
    private func startFakeServer(payload: String) throws -> UInt16 {
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in
                var response = Data("OKAY".utf8)
                response.append(AdbSocketFrameDecoder.encodeRequest(payload))
                conn.send(content: response, completion: .contentProcessed { _ in })
            }
        }
        let ready = expectation(description: "listener ready")
        listener.stateUpdateHandler = { if case .ready = $0 { ready.fulfill() } }
        listener.start(queue: .global())
        wait(for: [ready], timeout: 5)
        self.listener = listener
        return listener.port!.rawValue
    }

    private var listener: NWListener?
    override func tearDown() { listener?.cancel() }

    func test_start_receivesDeviceListFromServer() throws {
        let port = try startFakeServer(payload: "SERIAL1 device model:Pixel_8_Pro transport_id:1")
        let tracker = DeviceTracker(port: port)
        let got = expectation(description: "devices")
        tracker.onDevices = { devices in
            if devices == [Device(serial: "SERIAL1", state: .device, model: "Pixel_8_Pro")] {
                got.fulfill()
            }
        }
        tracker.start()
        wait(for: [got], timeout: 5)
        tracker.stop()
    }

    func test_start_noServer_firesDisconnect() {
        let tracker = DeviceTracker(port: closedPort()) // nothing listens here
        let disconnected = expectation(description: "disconnect")
        disconnected.assertForOverFulfill = false
        tracker.onDisconnect = { disconnected.fulfill() }
        tracker.start()
        wait(for: [disconnected], timeout: 5)
        tracker.stop()
    }
}
