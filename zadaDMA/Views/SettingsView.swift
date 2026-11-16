import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pairing = PairingController.shared
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pinCode: String = ""
    @State private var isPairing = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Device").foregroundColor(.gray)) {
                    HStack { Text("Model").foregroundColor(.gray); Spacer(); Text(state.deviceModel).foregroundColor(.white) }
                    HStack { Text("iOS Version").foregroundColor(.gray); Spacer(); Text(state.deviceiOS).foregroundColor(.white) }
                }
                
                Section(header: Text("Pairing & Tunnel").foregroundColor(.gray)) {
                    HStack {
                        Image(systemName: "network").foregroundColor(.orange)
                        Text("Tunnel").foregroundColor(.gray)
                        Spacer()
                        Text("Connected").foregroundColor(.green)
                    }
                    HStack {
                        Image(systemName: pairing.hasPairingFile ? "checkmark.circle.fill" : "exclamationmark.circle")
                            .foregroundColor(pairing.hasPairingFile ? .green : .gray)
                        Text("Pairing").foregroundColor(.gray)
                        Spacer()
                        Text(pairing.hasPairingFile ? "Ready" : "No file")
                            .foregroundColor(pairing.hasPairingFile ? .green : .white)
                    }
                }
                
                Section {
                    if !isPairing {
                        Button {
                            startPairing()
                        } label: {
                            Label("Pair on this iPhone", systemImage: "iphone")
                        }
                        .foregroundColor(.orange)
                    } else {
                        // Gjenerojme PIN dhe e shfaqim
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pairing PIN: \(pinCode)").font(.headline).foregroundColor(.white)
                            Text("Go to Settings → Privacy & Security → Developer Mode and enter this PIN.")
                                .font(.caption).foregroundColor(.gray)
                            Button("Stop Pairing") {
                                stopPairing()
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.orange)
                }
            }
            .alert("Pairing file u importua", isPresented: $showSuccess) { Button("OK") { } }
            .alert("Gabim", isPresented: $showError) { Button("OK") { } } message: { Text(errorMessage) }
        }
        .preferredColorScheme(.dark)
    }
    
    private func startPairing() {
        isPairing = true
        // Gjenerojme nje PIN 6-shifror
        pinCode = String(format: "%06d", Int.random(in: 0..<1000000))
        print("[Pairing] Starting pairing host with PIN: \(pinCode)")
        pairing.startPairing(pin: pinCode) { success in
            if success {
                DispatchQueue.main.async {
                    showSuccess = true
                    isPairing = false
                }
            } else {
                DispatchQueue.main.async {
                    errorMessage = "Pairing dështoi. Provo përsëri."
                    showError = true
                    isPairing = false
                }
            }
        }
    }
    
    private func stopPairing() {
        pairing.stopPairing()
        isPairing = false
        pinCode = ""
    }
}
