import SwiftUI
import Foundation

@MainActor
final class AppState: ObservableObject {
    // MARK: - Persisted settings (reactive)
    @Published var hasCompletedOnboarding: Bool = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }
    @Published var language: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "English" {
        didSet { UserDefaults.standard.set(language, forKey: "appLanguage") }
    }
    @Published var appearance: String = UserDefaults.standard.string(forKey: "appAppearance") ?? "System" {
        didSet { UserDefaults.standard.set(appearance, forKey: "appAppearance") }
    }
    @Published var selectedGame: String = UserDefaults.standard.string(forKey: "selectedGame") ?? "Free Fire" {
        didSet { UserDefaults.standard.set(selectedGame, forKey: "selectedGame") }
    }
    @Published var isActivated: Bool = UserDefaults.standard.bool(forKey: "isActivated") {
        didSet { UserDefaults.standard.set(isActivated, forKey: "isActivated") }
    }
    @Published var musicEnabled: Bool = UserDefaults.standard.bool(forKey: "musicEnabled") {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled") }
    }

    let appVersion = "0.2.0"

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
        let trace = MotorBridge.injectionTrace()
        if !trace.isEmpty {
            patchLog.append("ℹ️ Gjurma e provës së fundit:")
            for line in trace.split(separator: "\n").suffix(4) {
                patchLog.append("   \(line)")
            }
        }
        SoundManager.shared.play(sound: "welcome")
    }

    var colorScheme: ColorScheme? {
        if appearance == "Light" { return .light }
        if appearance == "Dark"  { return .dark }
        return nil
    }

    func t(_ key: String) -> String {
        Localization.shared.translate(key, lang: language)
    }

    func toggleFeature(_ name: String, isOn: Bool, patchFile: String? = nil) {
        if !isOn {
            SoundManager.shared.play(sound: "desactivar")
            setFeature(name, enabled: false)
            patchLog.append("❌ \(name) u deaktivizua.")
            return
        }
        guard let file = patchFile else {
            SoundManager.shared.play(sound: "activar")
            setFeature(name, enabled: true)
            patchLog.append("✅ \(name) u aktivizua.")
            return
        }
        guard Bundle.main.path(forResource: file, ofType: "3105") != nil else {
            patchLog.append("⚠️ \(name): patch-i nuk është në këtë build.")
            return
        }
        SoundManager.shared.play(sound: "activar")
        patchLog.append("⏳ \(name): duke injektuar…")
        applyPatchWithFallback(fileName: file) { [weak self] success in
            guard let self else { return }
            if success { self.setFeature(name, enabled: true) }
        }
    }

    private func setFeature(_ name: String, enabled: Bool) {
        switch name {
        case "AIM DRAG": aimbotDragEnabled = enabled
        case "AIM PECHO": aimPeitoEnabled = enabled
        case "HOLOGRAMA": hologramEnabled = enabled
        case "SKIN": skinEnabled = enabled
        default: break
        }
    }

    private func applyPatchWithFallback(fileName: String, completion: @escaping (Bool) -> Void) {
        // Runs MCM first, then Airlift (AirTraffic). Both block on daemon I/O,
        // so keep the whole attempt off the main thread.
        let bundleIDs = ["com.dts.freefireth", "com.dts.freefiremax"]
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            MotorBridge.resetInjectionTrace()
            let local = MotorBridge.applyPatchFile(fileName, bundleIDs: bundleIDs)
            let trace = MotorBridge.injectionTrace()
            let patched = local["patched"] as? [String] ?? []
            let localErrors = local["errors"] as? [String] ?? []
            let paths = local["paths"] as? [String] ?? []
            let error = local["error"] as? String

            DispatchQueue.main.async {
                guard let self else { return }
                if patched.isEmpty {
                    if let error { self.patchLog.append("⚠️ \(error)") }
                    for line in localErrors { self.patchLog.append("   \(line)") }
                    self.patchLog.append("⚠️ MCM dhe Airlift nuk arritën ta shkruajnë skedarin.")
                    let tail = trace.split(separator: "\n").suffix(10)
                    if !tail.isEmpty {
                        self.patchLog.append("ℹ️ Gjurma e fundit:")
                        for line in tail { self.patchLog.append("   \(line)") }
                    }
                    completion(false)
                    return
                }
                self.patchLog.append("✅ \(fileName) u injektua: \(patched.joined(separator: ", "))")
                if let first = paths.first { self.patchLog.append("   \(first)") }
                completion(true)
            }
        }
    }
}
