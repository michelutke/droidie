import Foundation

/// Decodes adb smart-socket frames (4 ASCII hex chars length + payload).
public struct AdbSocketFrameDecoder {
    private var buffer = Data()

    /// Initialize a new frame decoder.
    public init() {}

    /// Feed data into the decoder and extract complete frames.
    public mutating func feed(_ data: Data) -> [String] {
        buffer.append(data)
        var frames: [String] = []
        while buffer.count >= 4 {
            let start = buffer.startIndex
            guard let lenStr = String(data: buffer[start..<(start + 4)], encoding: .utf8),
                  let len = Int(lenStr, radix: 16) else {
                buffer.removeAll()
                break
            }
            guard buffer.count >= 4 + len else { break }
            let payloadStart = start + 4
            frames.append(String(data: buffer[payloadStart..<(payloadStart + len)], encoding: .utf8) ?? "")
            buffer = Data(buffer.dropFirst(4 + len))
        }
        return frames
    }

    /// Encode a request string with adb smart-socket framing.
    public static func encodeRequest(_ payload: String) -> Data {
        Data((String(format: "%04x", payload.utf8.count) + payload).utf8)
    }
}
