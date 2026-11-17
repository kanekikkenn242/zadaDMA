import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pairing = PairingController.shared
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                        Text(pairing.hasPairingFile ? "Ready" : "Not connected")
                            .foregroundColor(pairing.hasPairingFile ? .green : .gray)
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
                    if !pairing.isPairing {
                        Button {
                            startPairing()
                        } label: {
                            Label("Start Pairing (Developer Mode)", systemImage: "iphone")
                        }
                        .foregroundColor(.orange)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pairing.currentPin.isEmpty ? "Duke pritur iPhone-in…" : "Pairing PIN: \(pairing.currentPin)")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Hap Settings → Privacy & Security → Developer Mode → Pair with \"zadaDMA\" dhe shkruaj PIN-in.")
                                .font(.caption)
                                .foregroundColor(.gray)
                            if pairing.backgroundLimited {
                                Text("Kujdes: pa background task, ke ~30s para se iOS ta ndalojë app-in. Shko direkt në Settings.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
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
            .alert("Pairing u krye", isPresented: $showSuccess) { Button("OK") { } }
            .alert("Gabim", isPresented: $showError) { Button("OK") { } } message: { Text(errorMessage) }
        }
        .preferredColorScheme(.dark)
    }
    
    private func startPairing() {
        pairing.startPairing { success in
            DispatchQueue.main.async {
                if success {
                    showSuccess = true
                } else if !pairing.pairingStatus.contains("cancelled") {
                    errorMessage = pairing.pairingStatus
                    showError = true
                }
            }
        }
    }
    
    private func stopPairing() {
        pairing.stopPairing()
    }
}
