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
        get { defaults.string(forKey: "deviceDestPath") ?? "/storage/emulated/0/Download" }
        set { defaults.set(newValue, forKey: "deviceDestPath") }
    }

    /// Directory on macOS where downloaded files are saved.
    public var macDownloadDir: String {
        get { defaults.string(forKey: "macDownloadDir") ?? NSString("~/Downloads").expandingTildeInPath }
        set { defaults.set(newValue, forKey: "macDownloadDir") }
    }

    /// Optional path override for adb binary location.
    public var adbPathOverride: String? {
        get { defaults.string(forKey: "adbPathOverride") }
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
