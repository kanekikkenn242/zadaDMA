import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pairing = PairingController.shared
    @State private var isImporting = false
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
                        Text("Not connected").foregroundColor(.white)
                    }
                    HStack {
                        Image(systemName: "doc.badge.plus").foregroundColor(.orange)
                        Text("Pairing").foregroundColor(.gray)
                        Spacer()
                        Text(pairing.hasPairingFile ? "Imported" : "No file")
                            .foregroundColor(pairing.hasPairingFile ? .green : .white)
                    }
                }
                
                Section {
                    Button {
                        isImporting = true
                    } label: {
                        Label("Import pairing file", systemImage: "square.and.arrow.down")
                    }.foregroundColor(.orange)
                    
                    Button {
                        pairing.reloadPairingFile()
                        if pairing.hasPairingFile { showSuccess = true }
                        else { errorMessage = "Pairing.plist nuk u gjet. Vendose manualisht në Files app."; showError = true }
                    } label: {
                        Label("Refresh pairing status", systemImage: "arrow.clockwise")
                    }.foregroundColor(.orange)
                    
                    Button {
                        if let url = URL(string: "stosvpn://") { UIApplication.shared.open(url) }
                    } label: {
                        Label("Open LocalDevVPN", systemImage: "link")
                    }.foregroundColor(.orange)
                }
                
                Section(header: Text("Verified versions").foregroundColor(.gray)) {
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack { Text(ios).foregroundColor(.white); Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray) }
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
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        if pairing.importPairingFile(url: url) { showSuccess = true }
                        else { errorMessage = "Gabim gjatë importit."; showError = true }
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .alert("Pairing file u importua", isPresented: $showSuccess) { Button("OK") { } }
            .alert("Gabim", isPresented: $showError) { Button("OK") { } } message: { Text(errorMessage) }
        }
        .preferredColorScheme(.dark)
    }
}
