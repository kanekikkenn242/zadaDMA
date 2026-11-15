import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // E ndryshuam emrin e çelësit në "v2_..." që iOS ta harrojë statusin e vjetër
    @AppStorage("v2_hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguage") var language: String = "English"
    @AppStorage("appAppearance") var appearance: String = "System"
    @AppStorage("selectedGame") var selectedGame: String = "Free Fire"
    @AppStorage("isActivated") var isActivated: Bool = false
    
    @Published var licenseKey: String = ""
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    @Published var selectedCategory: String = "Aimbot"
    @Published var aimPeitoEnabled: Bool = false
    @Published var aimbotDragEnabled: Bool = false
    @Published var hologramEnabled: Bool = false
    @Published var skinEnabled: Bool = false
    
    @Published var patchLog: [String] = []
    
    init() {
        let info = DeviceInfo()
        self.deviceModel = info.modelName
        self.deviceiOS = info.systemVersion
        
        // Zeri i nisjes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SoundManager.shared.play(sound: "welcome")
        }
    }
    
    var colorScheme: ColorScheme? {
        if appearance == "Light" { return .light }
        if appearance == "Dark" { return .dark }
        return nil
    }
    
    func t(_ key: String) -> String {
        Localization.shared.translate(key, lang: language)
    }
    
    func toggleFeature(_ name: String, isOn: Bool, patchFile: String? = nil) {
        if isOn {
            SoundManager.shared.play(sound: "activar")
            patchLog.append("✅ \(name) u injektua.")
            if let file = patchFile {
                print("Duke aplikuar \(file).3105...")
            }
        } else {
            SoundManager.shared.play(sound: "desactivar")
            patchLog.append("❌ \(name) u deaktivizua.")
        }
    }
}
