import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var pairing = PairingController.shared
    @State private var showImporter = false
    @State private var importAlert = false
    @State private var importMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: Header
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 54))
                            .foregroundColor(.appOrange)
                        Text("zadaDMA")
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundColor(.white)
                        Text(state.deviceModel + " · iOS " + state.deviceiOS)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // MARK: Pairing card
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.appOrange)
                            Text("Developer Mode Pairing")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(pairing.hasPairingFile ? "READY" : "NOT PAIRED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(pairing.hasPairingFile ? .green : .gray)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((pairing.hasPairingFile ? Color.green : Color.gray).opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        // PIN display
                        HStack {
                            Text("PIN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            Spacer()
                            Text(pairing.currentPin.isEmpty ? "— — — — — —" : pairing.currentPin)
                                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                                .foregroundColor(pairing.currentPin.isEmpty ? .gray : .appOrange)
                        }
                        
                        // Button 1: generate PIN
                        Button {
                            _ = pairing.generatePin()
                        } label: {
                            HStack {
                                Image(systemName: "number")
                                Text("Generate 6-digit PIN")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appOrange)
                            .cornerRadius(10)
                        }
                        
                        // Button 2: import pairing.plist
                        Button {
                            showImporter = true
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import pairing.plist")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appCard)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appOrange.opacity(0.5), lineWidth: 1))
                        }
                        
                        Text("Developer Mode nuk liston aplikacione. Pairing bëhet nga PC/Mac (Xcode ose pymobiledevice3), pastaj importo pairing.plist këtu.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)

                        HStack(spacing: 6) {
                            Image(systemName: pairing.pairingStatus == "Paired" ? "checkmark.circle.fill" : "info.circle")
                                .font(.system(size: 10))
                                .foregroundColor(pairing.pairingStatus == "Paired" ? .green : .gray)
                            Text(pairing.pairingStatus)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(Color(white: 0.07))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: Status card
                    VStack(alignment: .leading, spacing: 10) {
                        StatusRow(icon: "network", title: "Tunnel", value: pairing.hasPairingFile ? "Connected" : "Not connected", ok: pairing.hasPairingFile)
                        StatusRow(icon: "checkmark.shield", title: "Pairing file", value: pairing.hasPairingFile ? "Loaded" : "Missing", ok: pairing.hasPairingFile)
                        StatusRow(icon: "bolt.fill", title: "Exploit", value: "Tap Game tab to patch", ok: true)
                    }
                    .padding(16)
                    .background(Color(white: 0.07))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // MARK: Log
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Activity")
                            .font(.caption)
                            .foregroundColor(.gray)
                        ForEach(state.patchLog.suffix(4), id: \.self) { line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if state.patchLog.isEmpty {
                            Text("No activity yet.")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black)
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarHidden(true)
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.item],
                          allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let ok = pairing.importPairingFile(url: url)
                    importMessage = ok
                        ? "✅ pairing.plist u importua. Statusi: \(pairing.pairingStatus)"
                        : "❌ Import dështoi.\n\(pairing.pairingStatus)"
                    importAlert = true
                case .failure(let error):
                    importMessage = "❌ Zgjedhja e file-it dështoi.\n\(error.localizedDescription)"
                    importAlert = true
                }
            }
            .alert("Import pairing.plist", isPresented: $importAlert) {
                Button("OK") { }
            } message: {
                Text(importMessage)
            }
        }
    }
}

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let ok: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(ok ? .green : .gray)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(ok ? .white : .gray)
        }
    }
}
