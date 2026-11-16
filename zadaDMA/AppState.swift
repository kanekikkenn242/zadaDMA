import SwiftUI
import Foundation

@MainActor
final class AppState: ObservableObject {
    // MARK: - Onboarding & Settings
    @AppStorage("v2_hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("appLanguage") var language: String = "English"
    @AppStorage("appAppearance") var appearance: String = "System"
    @AppStorage("selectedGame") var selectedGame: String = "Free Fire"
    @AppStorage("isActivated") var isActivated: Bool = false
    
    // MARK: - Device Info
    @Published var licenseKey: String = ""
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // MARK: - Free Fire Features
    @Published var selectedCategory: String = "Aimbot"
    @Published var aimPeitoEnabled: Bool = false
    @Published var aimbotDragEnabled: Bool = false
    @Published var hologramEnabled: Bool = false
    @Published var skinEnabled: Bool = false
    
    // MARK: - Logs
    @Published var patchLog: [String] = []
    
    // MARK: - Init
    init() {
        let info = DeviceInfo()
        self.deviceModel = info.modelName
        self.deviceiOS = info.systemVersion
        
        // Play welcome sound after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SoundManager.shared.play(sound: "welcome")
        }
    }
    
    // MARK: - Appearance
    var colorScheme: ColorScheme? {
        if appearance == "Light" { return .light }
        if appearance == "Dark" { return .dark }
        return nil
    }
    
    // MARK: - Localization Helper
    func t(_ key: String) -> String {
        Localization.shared.translate(key, lang: language)
    }
    
    // MARK: - Feature Toggle
    func toggleFeature(_ name: String, isOn: Bool, patchFile: String? = nil) {
        if isOn {
            SoundManager.shared.play(sound: "activar")
            patchLog.append("✅ \(name) u aktivizua.")
            if let file = patchFile {
                applyPatchWithFallback(fileName: file)
            }
        } else {
            SoundManager.shared.play(sound: "desactivar")
            patchLog.append("❌ \(name) u deaktivizua.")
        }
    }
    
    // MARK: - Patch Application with Fallback
    private func applyPatchWithFallback(fileName: String) {
        // 1. Try kexploit (works on iOS 17-26)
        if MotorBridge.bootstrap() {
            if MotorBridge.applyPatch(fileName) {
                patchLog.append("✅ \(fileName) u injektua me kexploit.")
                return
            }
        }
        
        // 2. kexploit failed -> use Airlift
        patchLog.append("⚠️ kexploit dështoi. Duke provuar Airlift...")
        
        // Get local .3105 file path
        guard let path = Bundle.main.path(forResource: fileName, ofType: "3105") else {
            patchLog.append("❌ Skedari .3105 mungon në bundle.")
            return
        }
        
        // Get Free Fire container path via Airlift
        guard let container = PairingController.shared.getContainerPath(bundleID: "com.dts.freefireth") else {
            patchLog.append("❌ Container-i i Free Fire nuk u gjet (Airlift).")
            return
        }
        
        // Construct remote path
        let remotePath = container + "/Data/Raw/ios/gameassetbundles/avatar/assetindexer.tdn~2F53YNFWXQZyPdFl8HWBBwtXk~3D"
        
        // Inject file via Airlift
        if PairingController.shared.injectFile(localPath: path, remotePath: remotePath) {
            patchLog.append("✅ \(fileName) u injektua me Airlift.")
        } else {
            patchLog.append("❌ Airlift dështoi. A është LocalDevVPN aktiv?")
        }
    }
}
