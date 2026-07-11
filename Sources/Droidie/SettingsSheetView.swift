import SwiftUI
import DroidieCore

struct SettingsSheetView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var deviceDestPath = ""
    @State private var macDownloadDir = ""
    @State private var adbPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)

            Text("Device destination folder").font(.caption)
            TextField("/sdcard/Download", text: $deviceDestPath)

            Text("Mac download folder").font(.caption)
            TextField("~/Downloads", text: $macDownloadDir)

            Text("adb path override (empty = auto-detect: \(appState.adbPath ?? "not found"))").font(.caption)
            TextField("", text: $adbPath)

            Text("adb path changes take effect after restarting Droidie.")
                .font(.caption2).foregroundStyle(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    appState.settings.deviceDestPath = deviceDestPath
                    appState.settings.macDownloadDir = NSString(string: macDownloadDir).expandingTildeInPath
                    appState.settings.adbPathOverride = adbPath.isEmpty ? nil : adbPath
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .frame(width: 360)
        .onAppear {
            deviceDestPath = appState.settings.deviceDestPath
            macDownloadDir = appState.settings.macDownloadDir
            adbPath = appState.settings.adbPathOverride ?? ""
        }
    }
}
