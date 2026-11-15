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
    @Published var deviceBuild: String = ""
    
    // Free Fire Toggles
    @Published var aimPeitoEnabled: Bool = false
    @Published var aimbotDragEnabled: Bool = false

    init() {
        let info = DeviceInfo()
        self.deviceModel = info.modelName
        self.deviceiOS = info.systemVersion
        self.deviceBuild = info.buildVersion
    }
    
    var colorScheme: ColorScheme? {
        if appearance == "Light" { return .light }
        if appearance == "Dark" { return .dark }
        return nil
    }
    
    func t(_ key: String) -> String {
        return Localization.shared.translate(key, lang: language)
    }
}
