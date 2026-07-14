import AppKit

/// Transparent view layered over the status item button: forwards clicks, accepts file drops.
final class DropCatcherView: NSView {
    var onClick: (() -> Void)?
    var onFiles: (([URL]) -> Bool)?
    /// Fired when a file drag hovers over the icon — used to open the popover mid-drag.
    var onDragEntered: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                         options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        guard !urls.isEmpty else { return false }
        return onFiles?(urls) ?? false
    }
}
