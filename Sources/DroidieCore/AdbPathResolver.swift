import Foundation

/// Resolves the path to the adb binary by checking override, standard locations, and PATH.
public struct AdbPathResolver {
    private let override: String?
    private let environment: [String: String]
    private let fileExists: (String) -> Bool

    /// Initializes the resolver with optional override, environment, and file existence check.
    public init(override: String? = nil,
                environment: [String: String] = ProcessInfo.processInfo.environment,
                fileExists: @escaping (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) {
        self.override = override
        self.environment = environment
        self.fileExists = fileExists
    }

    /// Resolves the adb binary path: override → /opt/homebrew/bin/adb → /usr/local/bin/adb → PATH dirs.
    public func resolve() -> String? {
        var candidates: [String] = []
        if let override { candidates.append(override) }
        candidates.append("/opt/homebrew/bin/adb")
        candidates.append("/usr/local/bin/adb")
        for dir in (environment["PATH"] ?? "").split(separator: ":") {
            candidates.append(String(dir) + "/adb")
        }
        return candidates.first(where: fileExists)
    }
}
