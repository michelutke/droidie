import Foundation

/// Remote entry parsed from Android device `ls -la` output.
public struct RemoteEntry: Equatable, Identifiable, Sendable {
    /// The file or directory name.
    public let name: String
    /// Whether this entry is a directory.
    public let isDirectory: Bool
    /// File size in bytes.
    public let size: Int64

    public var id: String { name }

    /// Initialize a remote entry.
    public init(name: String, isDirectory: Bool, size: Int64) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
    }
}

/// Parses Android toybox `ls -la` output into structured entries (directories first, then alphabetical).
public enum LsParser {
    /// Parses `ls -la` output, skipping total/./.. entries, returns directories first then alphabetical.
    public static func parse(_ output: String) -> [RemoteEntry] {
        let entries: [RemoteEntry] = output.split(separator: "\n").compactMap { line in
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            // perms links owner group size date time name...
            guard parts.count >= 8, parts[0].count >= 10, "d-lbcsp".contains(parts[0].first!) else { return nil }
            var name = parts[7...].joined(separator: " ")
            let isSymlink = parts[0].hasPrefix("l")
            if isSymlink, let arrowRange = name.range(of: " -> ") {
                name = String(name[name.startIndex..<arrowRange.lowerBound])
            }
            guard name != ".", name != ".." else { return nil }
            // Treat symlinks as directories: on Android the common symlinks (/sdcard,
            // /storage/self/primary) point to directories, so this lets navigation work.
            let isDirectory = parts[0].hasPrefix("d") || isSymlink
            return RemoteEntry(name: name, isDirectory: isDirectory, size: Int64(parts[4]) ?? 0)
        }
        return entries.sorted {
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
