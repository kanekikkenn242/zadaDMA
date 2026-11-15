import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text(state.t("language")).foregroundColor(.gray)) {
                    Picker("Language", selection: $state.language) {
                        ForEach(["Español", "English", "Português"], id: \.self) { lang in Text(lang).tag(lang) }
                    }.pickerStyle(.segmented)
                }
                
                Section(header: Text(state.t("appearance")).foregroundColor(.gray)) {
                    Picker("Appearance", selection: $state.appearance) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { app in Text(state.t(app.lowercased())).tag(app) }
                    }.pickerStyle(.segmented)
                }
                
                Section(header: Text(state.t("device_status")).foregroundColor(.gray)) {
                    HStack { Text(state.t("hardware")).foregroundColor(.gray); Spacer(); Text(state.deviceModel).foregroundColor(.white) }
                    HStack { Text(state.t("ios")).foregroundColor(.gray); Spacer(); Text(state.deviceiOS).foregroundColor(.white) }
                }
                
                Section(header: Text("Pairing & Tunnel").foregroundColor(.gray)) {
                    HStack { Image(systemName: "exclamationmark.circle.fill").foregroundColor(.appOrange); Text(state.t("tunnel")).foregroundColor(.gray); Spacer(); Text(state.t("not_conn")).foregroundColor(.white) }
                    HStack { Image(systemName: "exclamationmark.circle.fill").foregroundColor(.appOrange); Text(state.t("pairing")).foregroundColor(.gray); Spacer(); Text(state.t("no_file")).foregroundColor(.white) }
                    HStack { Image(systemName: "checkmark.seal.fill").foregroundColor(.green); Text(state.t("compat")).foregroundColor(.gray); Spacer(); Text(state.t("supported_ios")).foregroundColor(.green) }
                }
                
                Section {
                    Button(state.t("open_vpn")) {}
                    Button(state.t("import_pair")) {}
                }.foregroundColor(.appOrange)
                
                Section(header: Text(state.t("verified")).foregroundColor(.gray)) {
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack { Text(ios).foregroundColor(.white); Spacer(); Image(systemName: "chevron.right").foregroundColor(.gray) }
                    }
                }
            }
            .listStyle(.insetGrouped).background(Color.black.ignoresSafeArea())
            .navigationTitle(state.t("settings")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(state.t("done")) { dismiss() }.foregroundColor(.appOrange) } }
        }.preferredColorScheme(state.colorScheme)
    }
}
