import SwiftUI
import DroidieCore

struct PopoverView: View {
    @ObservedObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        if appState.adbPath == nil {
            OnboardingView(appState: appState)
        } else {
            VStack(spacing: 0) {
                if let deviceStore = appState.deviceStore {
                    DeviceRowView(deviceStore: deviceStore)
                }
                Divider()
                TabView {
                    if let transferQueue = appState.transferQueue {
                        SendTabView(appState: appState, transferQueue: transferQueue)
                            .tabItem { Text("Send") }
                    }
                    if let deviceStore = appState.deviceStore, let transferQueue = appState.transferQueue {
                        BrowseTabView(appState: appState, deviceStore: deviceStore, transferQueue: transferQueue)
                            .tabItem { Text("Browse") }
                    }
                }
                Divider()
                HStack {
                    Spacer()
                    Button {
                        showSettings = true
                    } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain)
                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: { Image(systemName: "power") }
                    .buttonStyle(.plain)
                }
                .padding(8)
            }
            .frame(width: 380, height: 480)
            .sheet(isPresented: $showSettings) { SettingsSheetView(appState: appState) }
        }
    }
}
