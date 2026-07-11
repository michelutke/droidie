import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle").font(.largeTitle)
            Text("adb not found").font(.headline)
            Text("Install Android platform tools:")
            Text("brew install android-platform-tools")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(6)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text("…or set a custom adb path in Settings, then restart Droidie.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Open Settings") { showSettings = true }
        }
        .padding(24)
        .frame(width: 380, height: 480)
        .sheet(isPresented: $showSettings) { SettingsSheetView(appState: appState) }
    }
}
