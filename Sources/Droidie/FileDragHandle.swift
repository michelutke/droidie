import AppKit
import SwiftUI
import UniformTypeIdentifiers
import DroidieCore

/// Drag handle for a device file row. Uses an AppKit NSFilePromiseProvider drag —
/// Finder resolves the promise by calling writePromiseTo with the exact drop
/// destination, and the file is adb-pulled straight there (no temp copy).
/// SwiftUI's Transferable file promises are not honored by Finder on macOS 14.
struct FileDragHandle: NSViewRepresentable {
    let remotePath: String
    let fileName: String
    let serial: String
    let adbPath: String

    func makeNSView(context: Context) -> FilePromiseDragView {
        let view = FilePromiseDragView()
        view.configure(remotePath: remotePath, fileName: fileName, serial: serial, adbPath: adbPath)
        return view
    }

    func updateNSView(_ nsView: FilePromiseDragView, context: Context) {
        nsView.configure(remotePath: remotePath, fileName: fileName, serial: serial, adbPath: adbPath)
    }
}

final class FilePromiseDragView: NSView, NSDraggingSource {
    private var promiseDelegate: RemoteFilePromiseDelegate?
    private var mouseDownEvent: NSEvent?

    func configure(remotePath: String, fileName: String, serial: String, adbPath: String) {
        promiseDelegate = RemoteFilePromiseDelegate(remotePath: remotePath, fileName: fileName,
                                                    serial: serial, adbPath: adbPath)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let downEvent = mouseDownEvent, let promiseDelegate else { return }
        mouseDownEvent = nil

        let fileType = UTType(filenameExtension: (promiseDelegate.fileName as NSString).pathExtension)?
            .identifier ?? UTType.data.identifier
        let provider = NSFilePromiseProvider(fileType: fileType, delegate: promiseDelegate)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let dragImage = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        item.setDraggingFrame(NSRect(x: 0, y: 0, width: 24, height: 24), contents: dragImage)
        beginDraggingSession(with: [item], event: downEvent, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }
}

final class RemoteFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    let remotePath: String
    let fileName: String
    let serial: String
    let adbPath: String

    private static let workQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "droidie.file-promise"
        return queue
    }()

    init(remotePath: String, fileName: String, serial: String, adbPath: String) {
        self.remotePath = remotePath
        self.fileName = fileName
        self.serial = serial
        self.adbPath = adbPath
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                             fileNameForType fileType: String) -> String {
        fileName
    }

    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        Self.workQueue
    }

    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider,
                             writePromiseTo url: URL,
                             completionHandler: @escaping (Error?) -> Void) {
        let runner = AdbCommandRunner(adbPath: adbPath)
        let args = ["-s", serial, "pull", remotePath, url.path]
        Task {
            do {
                let result = try await runner.run(args, onOutput: nil)
                if result.exitCode == 0 {
                    completionHandler(nil)
                } else {
                    let message = result.stderr.isEmpty ? result.stdout : result.stderr
                    completionHandler(FilePromisePullError(message: message))
                }
            } catch {
                completionHandler(error)
            }
        }
    }
}

struct FilePromisePullError: LocalizedError {
    let message: String
    var errorDescription: String? { "Pull failed: \(message.trimmingCharacters(in: .whitespacesAndNewlines))" }
}
