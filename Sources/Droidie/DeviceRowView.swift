import SwiftUI
import DroidieCore

struct DeviceRowView: View {
    @ObservedObject var deviceStore: DeviceStore
    @State private var showPairing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Picker("", selection: $deviceStore.selectedSerial) {
                    if deviceStore.devices.isEmpty {
                        Text("No device").tag(String?.none)
                    }
                    ForEach(deviceStore.devices) { device in
                        HStack {
                            Circle()
                                .fill(color(for: device.state))
                                .frame(width: 8, height: 8)
                            Text("\(device.displayName) · \(device.transport == .usb ? "USB" : "WiFi")")
                        }
                        .tag(String?.some(device.serial))
                    }
                }
                .labelsHidden()

                Button("+ Pair") { showPairing = true }
            }

            if deviceStore.selectedDevice?.state == .unauthorized {
                Text("Confirm the debugging prompt on your phone")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            ForEach(deviceStore.offlineRememberedEndpoints(), id: \.self) { endpoint in
                HStack {
                    Text("\(endpoint) offline").font(.caption).foregroundStyle(.secondary)
                    Button("⟳ Reconnect") {
                        Task { await deviceStore.reconnect(endpoint: endpoint) }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(8)
        .sheet(isPresented: $showPairing) {
            PairingSheetView(deviceStore: deviceStore)
        }
    }

    private func color(for state: Device.State) -> Color {
        switch state {
        case .device: .green
        case .unauthorized: .yellow
        default: .gray
        }
    }
}
