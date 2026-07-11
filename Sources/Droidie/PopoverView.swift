import SwiftUI
import DroidieCore

struct PopoverView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        if appState.adbPath == nil {
            Text("adb not found — onboarding comes in Task 17")
                .padding()
                .frame(width: 380, height: 480)
        } else {
            VStack(spacing: 0) {
                Text("device row — Task 14").padding(8)
                Divider()
                TabView {
                    Text("Send — Task 15").tabItem { Text("Send") }
                    Text("Browse — Task 16").tabItem { Text("Browse") }
                }
                Divider()
                HStack {
                    Spacer()
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: { Image(systemName: "power") }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
            .frame(width: 380, height: 480)
        }
    }
}
