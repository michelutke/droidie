import Foundation

/// User settings backed by UserDefaults for persisting app configuration.
public final class AppSettings {
    private let defaults: UserDefaults

    /// Initializes AppSettings with a given UserDefaults suite.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Destination path on Android device for transferred files.
    public var deviceDestPath: String {
        get {
            let stored = defaults.string(forKey: "deviceDestPath") ?? ""
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "/storage/emulated/0/Download" : stored
        }
        set { defaults.set(newValue, forKey: "deviceDestPath") }
    }

    /// Directory on macOS where downloaded files are saved.
    public var macDownloadDir: String {
        get {
            let stored = defaults.string(forKey: "macDownloadDir") ?? ""
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? NSString("~/Downloads").expandingTildeInPath : stored
        }
        set { defaults.set(newValue, forKey: "macDownloadDir") }
    }

    /// Optional path override for adb binary location.
    public var adbPathOverride: String? {
        get {
            let stored = defaults.string(forKey: "adbPathOverride") ?? ""
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : stored
        }
        set { defaults.set(newValue, forKey: "adbPathOverride") }
    }

    /// List of remembered WiFi connection endpoints (ip:port format).
    public var rememberedWifiEndpoints: [String] {
        get { defaults.stringArray(forKey: "rememberedWifiEndpoints") ?? [] }
        set { defaults.set(newValue, forKey: "rememberedWifiEndpoints") }
    }

    /// Adds or moves an endpoint to the front of the remembered list, removing duplicates.
    public func rememberWifiEndpoint(_ endpoint: String) {
        var list = rememberedWifiEndpoints.filter { $0 != endpoint }
        list.insert(endpoint, at: 0)
        rememberedWifiEndpoints = list
    }
}
