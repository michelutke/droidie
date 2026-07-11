import AppKit
import Combine
import SwiftUI
import DroidieCore

@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let appState: AppState
    private var cancellable: AnyCancellable?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "smartphone",
                                           accessibilityDescription: "Droidie")

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 480)
        popover.contentViewController = NSHostingController(rootView: PopoverView(appState: appState))

        if let button = statusItem.button {
            let catcher = DropCatcherView(frame: button.bounds)
            catcher.autoresizingMask = [.width, .height]
            catcher.onClick = { [weak self] in self?.togglePopover() }
            catcher.onFiles = { [weak self] urls in self?.appState.pushToSelectedDevice(urls); _ = self }
            button.addSubview(catcher)
        }

        if let queue = appState.transferQueue {
            cancellable = queue.$jobs
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    if let percent = queue.overallPercent {
                        self.statusItem.button?.title = " \(percent)%"
                    } else {
                        self.statusItem.button?.title = ""
                    }
                }
            statusItem.button?.imagePosition = .imageLeft
        }
    }

    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
