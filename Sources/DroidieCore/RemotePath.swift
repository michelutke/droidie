import Foundation

/// POSIX single-quote path escaping and joining for remote Android device paths.
public enum RemotePath {
    /// Escapes a path with POSIX single quotes.
    public static func quoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Joins a directory and filename, handling trailing slashes.
    public static func join(_ dir: String, _ name: String) -> String {
        dir.hasSuffix("/") ? dir + name : dir + "/" + name
    }
}
