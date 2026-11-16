import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @StateObject private var pairing = PairingController.shared
    @State private var isImporting = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Device").foregroundColor(.gray)) {
                    row(title: "Hardware model", value: state.deviceModel)
                    row(title: "iOS Version", value: state.deviceiOS)
                }
                
                Section(header: Text("Pairing & Tunnel").foregroundColor(.gray)) {
                    HStack {
                        Image(systemName: "network").foregroundColor(.appOrange)
                        Text("Tunnel").foregroundColor(.gray)
                        Spacer()
                        Text("Not connected").foregroundColor(.white)
                    }
                    HStack {
                        Image(systemName: "doc.badge.plus").foregroundColor(.appOrange)
                        Text("Pairing status").foregroundColor(.gray)
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
                    }
                    .foregroundColor(.appOrange)
                    
                    Button {
                        if let url = URL(string: "stosvpn://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open LocalDevVPN", systemImage: "link")
                    }
                    .foregroundColor(.appOrange)
                }
                
                Section(header: Text("Verified versions").foregroundColor(.gray)) {
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack {
                            Text(ios).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.gray)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.appOrange)
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.propertyList, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        if pairing.importPairingFile(url: url) {
                            showSuccess = true
                        }
                    }
                case .failure(let error):
                    print("[-] Gabim: \(error)")
                }
            }
            .alert("Pairing file u importua", isPresented: $showSuccess) {
                Button("OK") { }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.white)
        }
    }
}
