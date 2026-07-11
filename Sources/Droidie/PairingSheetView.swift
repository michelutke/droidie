import SwiftUI
import DroidieCore

struct PairingSheetView: View {
    @ObservedObject var deviceStore: DeviceStore
    @Environment(\.dismiss) private var dismiss

    @State private var pairingEndpoint = ""
    @State private var code = ""
    @State private var connectEndpoint = ""
    @State private var errorText: String?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pair over WiFi").font(.headline)
            Text("Phone: Settings → Developer options → Wireless debugging → Pair device with pairing code")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Pairing IP:port (e.g. 192.168.1.42:37123)", text: $pairingEndpoint)
            TextField("6-digit pairing code", text: $code)
            TextField("Connect IP:port (shown on main Wireless debugging screen)", text: $connectEndpoint)

            if let errorText {
                Text(errorText).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button(busy ? "Pairing…" : "Pair & Connect") {
                    busy = true
                    Task {
                        let error = await deviceStore.pair(pairingEndpoint: pairingEndpoint,
                                                           code: code,
                                                           connectEndpoint: connectEndpoint)
                        busy = false
                        if let error { errorText = error } else { dismiss() }
                    }
                }
                .disabled(busy || pairingEndpoint.isEmpty || code.count != 6 || connectEndpoint.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(16)
        .frame(width: 340)
    }
}
