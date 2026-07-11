import Foundation

public struct Device: Equatable, Identifiable, Sendable {
    public enum State: String, Sendable {
        case device, unauthorized, offline, unknown
    }
    public enum Transport: Equatable, Sendable { case usb, tcp }

    public let serial: String
    public let state: State
    public let model: String?

    public init(serial: String, state: State, model: String?) {
        self.serial = serial
        self.state = state
        self.model = model
    }

    public var id: String { serial }
    public var transport: Transport { serial.contains(":") ? .tcp : .usb }
    public var displayName: String {
        model?.replacingOccurrences(of: "_", with: " ") ?? serial
    }
}
