import CoreTransferable
import Foundation
import UniformTypeIdentifiers
import DroidieCore

/// Drag payload for a file on the Android device. Exports a file promise:
/// when dropped in Finder, the file is pulled via adb to a temp location and
/// Finder copies it to the drop target.
struct RemoteFileDrag: Transferable {
    let remotePath: String
    let fileName: String
    let serial: String
    let adbPath: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { drag in
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("droidie-drag-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let destination = tempDir.appendingPathComponent(drag.fileName)

            let runner = AdbCommandRunner(adbPath: drag.adbPath)
            let result = try await runner.run(["-s", drag.serial, "pull", drag.remotePath, destination.path],
                                              onOutput: nil)
            guard result.exitCode == 0 else {
                throw RemoteFileDragError(message: result.stderr.isEmpty ? result.stdout : result.stderr)
            }
            return SentTransferredFile(destination, allowAccessingOriginalFile: true)
        }
    }
}

struct RemoteFileDragError: LocalizedError {
    let message: String
    var errorDescription: String? { "Pull failed: \(message)" }
}
