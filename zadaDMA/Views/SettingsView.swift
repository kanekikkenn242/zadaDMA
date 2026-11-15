import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Device").foregroundColor(.gray)) {
                    SettingsRow(title: "Hardware model", value: state.deviceModel)
                    SettingsRow(title: "iOS Version", value: state.deviceiOS)
                }
                Section(header: Text("Pairing & Tunnel").foregroundColor(.gray)) {
                    HStack { Image(systemName: "xmark.circle.fill").foregroundColor(.appOrange); Text("Tunnel connection").foregroundColor(.gray); Spacer(); Text("Not connected").foregroundColor(.white) }
                    HStack { Image(systemName: "exclamationmark.circle.fill").foregroundColor(.appOrange); Text("Pairing status").foregroundColor(.gray); Spacer(); Text("No pairing file").foregroundColor(.white) }
                }
                Section {
                    Button("Open LocalDevVPN to connect") {}
                    Button("Import pairing file") {}
                }.foregroundColor(.appOrange)
                
                Section(header: Text("Verified versions").foregroundColor(.gray)) {
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack { Text(ios).foregroundColor(.white); Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray) }
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
        }.preferredColorScheme(.dark)
    }
}

struct SettingsRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundColor(.gray)
            Spacer()
            Text(value).foregroundColor(.white)
        }
    }
}
