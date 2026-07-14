import Foundation

public enum TrackDevicesParser {
    public static func parse(_ payload: String) -> [Device] {
        payload.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 2 else { return nil }
            let state = Device.State(rawValue: parts[1]) ?? .unknown
            let model = parts.dropFirst(2)
                .first { $0.hasPrefix("model:") }
                .map { String($0.dropFirst("model:".count)) }
            return Device(serial: parts[0], state: state, model: model)
        }
    }
}
