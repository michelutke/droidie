import Foundation

/// Extracts the last progress percentage from adb push/pull output.
public enum ProgressParser {
    /// Extracts the last `[ NN%]` occurrence in a stdout chunk, or nil if none found.
    public static func percent(in chunk: String) -> Int? {
        let pattern = "\\[\\s*(\\d{1,3})%\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = chunk as NSString
        var last: Int?
        let matches = regex.matches(in: chunk, range: NSRange(location: 0, length: nsString.length))
        for match in matches {
            if let range = Range(match.range(at: 1), in: chunk) {
                last = Int(chunk[range])
            }
        }
        return last
    }
}
