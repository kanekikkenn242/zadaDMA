import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SoundManager.shared.play(sound: "launch")
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
    
    func toggleFeature(_ name: String, isOn: Bool) {
        if isOn {
            SoundManager.shared.play(sound: "activate")
            patchLog.append("✅ \(name) u injektua.")
        } else {
            SoundManager.shared.play(sound: "deactivate")
            patchLog.append("❌ \(name) u deaktivizua.")
        }
    }
}
