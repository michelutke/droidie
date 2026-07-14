import Foundation
import Network

/// Tracks connected Android devices via a persistent adb server socket subscription.
public final class DeviceTracker: @unchecked Sendable {
    /// Invoked on the tracker's internal queue with the latest full device-list snapshot.
    public var onDevices: (@Sendable ([Device]) -> Void)?
    /// Invoked on the tracker's internal queue when the connection fails or closes.
    public var onDisconnect: (@Sendable () -> Void)?

    private let port: UInt16
    private var connection: NWConnection?
    private var decoder = AdbSocketFrameDecoder()
    private var sawOkay = false
    private var handshakeBuffer = Data()
    private var stopped = false
    private let queue = DispatchQueue(label: "droidie.device-tracker")

    /// Create a tracker that will connect to the adb server on the given port.
    public init(port: UInt16 = 5037) {
        self.port = port
    }

    /// Connect to the adb server and begin streaming device-list snapshots.
    public func start() {
        queue.async { [self] in
            stopped = false
            sawOkay = false
            handshakeBuffer = Data()
            decoder = AdbSocketFrameDecoder()
            let conn = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            connection = conn
            conn.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    conn.send(content: AdbSocketFrameDecoder.encodeRequest("host:track-devices-l"),
                              completion: .contentProcessed { _ in })
                    self.receiveLoop(conn)
                case .failed, .cancelled, .waiting:
                    // Deliberate fail-fast: .waiting is retryable (e.g. adb server not yet up),
                    // but the owner (DeviceStore) restarts tracking with `adb start-server` +
                    // backoff on every disconnect, so treating .waiting the same as a hard
                    // disconnect is the intended recovery path, not a bug.
                    self.disconnect()
                default:
                    break
                }
            }
            conn.start(queue: queue)
        }
    }

    /// Stop tracking and suppress any further callbacks.
    public func stop() {
        queue.async { [self] in
            stopped = true
            connection?.cancel()
            connection = nil
        }
    }

    private func receiveLoop(_ conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self, !self.stopped else { return }
            if var data, !data.isEmpty {
                if !self.sawOkay {
                    self.handshakeBuffer.append(data)
                    guard self.handshakeBuffer.count >= 4 else { return self.receiveLoop(conn) }
                    let status = String(data: self.handshakeBuffer.prefix(4), encoding: .utf8)
                    guard status == "OKAY" else { return self.disconnect() }
                    self.sawOkay = true
                    data = self.handshakeBuffer.dropFirst(4)
                    self.handshakeBuffer = Data()
                }
                for payload in self.decoder.feed(data) {
                    self.onDevices?(TrackDevicesParser.parse(payload))
                }
            }
            if isComplete || error != nil {
                self.disconnect()
            } else {
                self.receiveLoop(conn)
            }
        }
    }

    private func disconnect() {
        guard !stopped else { return }
        stopped = true
        connection?.cancel()
        connection = nil
        onDisconnect?()
    }
}
