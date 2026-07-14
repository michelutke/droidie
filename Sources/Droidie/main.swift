import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private let appState = AppState.bootstrap()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(appState: appState)
        appState.startServices()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
