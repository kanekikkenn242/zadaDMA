import SwiftUI
struct SettingsView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        NavigationStack {
            List {
                Section("Sandbox") { Text(state.sandboxReady ? "active" : "not active") }
                Section("Log") { ForEach(state.log, id: \.self) { Text($0).font(.system(.caption, design: .monospaced)) } }
            }.navigationTitle("Settings")
        }
    }
}
