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
    // Persisted so a jetsammed app still shows the card as active: the mod may
    // be on the device even when the UI was killed in the background.
    @Published var aimPeitoEnabled: Bool = UserDefaults.standard.bool(forKey: "aimPeitoEnabled") {
        didSet { UserDefaults.standard.set(aimPeitoEnabled, forKey: "aimPeitoEnabled") }
    }
    @Published var aimbotDragEnabled: Bool = UserDefaults.standard.bool(forKey: "aimbotDragEnabled") {
        didSet { UserDefaults.standard.set(aimbotDragEnabled, forKey: "aimbotDragEnabled") }
    }
    @Published var hologramEnabled: Bool = UserDefaults.standard.bool(forKey: "hologramEnabled") {
        didSet { UserDefaults.standard.set(hologramEnabled, forKey: "hologramEnabled") }
    }
    @Published var skinEnabled: Bool = UserDefaults.standard.bool(forKey: "skinEnabled") {
        didSet { UserDefaults.standard.set(skinEnabled, forKey: "skinEnabled") }
    }

    @Published var patchLog: [String] = []

    /// Guards overlapping MCM/Airlift transactions (double taps on a card).
    private var patchInFlight = false
    private var traceTimer: Timer?
    private var traceLineCount = 0

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
        guard !patchInFlight else {
            patchLog.append("⏳ Prit derisa veprimi i mëparshëm të përfundojë.")
            return
        }
        if !isOn {
            SoundManager.shared.play(sound: "desactivar")
            guard let file = patchFile else {
                setFeature(name, enabled: false)
                patchLog.append("❌ \(name) u deaktivizua.")
                return
            }
            guard Bundle.main.path(forResource: file, ofType: "3105") != nil else {
                patchLog.append("⚠️ \(name): patch-i nuk është në këtë build.")
                return
            }
            // Anti-cheat flow: the card may only turn off after the exact
            // original bytes are back on the device.
            patchLog.append("⏳ \(name): duke kthyer origjinalin…")
            restorePatchWithFallback(fileName: file) { [weak self] success in
                guard let self else { return }
                guard success else {
                    self.patchLog.append("⚠️ \(name): origjinali nuk u kthye; karta mbeti aktive.")
                    return
                }
                self.setFeature(name, enabled: false)
                self.patchLog.append("✅ \(name) u deaktivizua; origjinali u kthye.")
                self.reapplyRemainingAim(after: name)
            }
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

    private func startTraceStreaming() {
        traceLineCount = 0
        traceTimer?.invalidate()
        // The native call blocks until MCM/Airlift finishes. Mirror its trace
        // into the visible log so a stalled step is identifiable on-device.
        traceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.drainTrace()
            }
        }
    }

    private func drainTrace() {
        guard patchInFlight else { return }
        let lines = MotorBridge.injectionTrace()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        guard lines.count > traceLineCount else { return }
        let fresh = lines[traceLineCount...]
        traceLineCount = lines.count
        for line in fresh where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            patchLog.append("· \(line)")
        }
    }

    private func stopTraceStreaming() {
        traceTimer?.invalidate()
        traceTimer = nil
    }

    private func applyPatchWithFallback(fileName: String, completion: @escaping (Bool) -> Void) {
        // Runs MCM first, then Airlift (AirTraffic). Both block on daemon I/O,
        // so keep the whole attempt off the main thread.
        patchInFlight = true
        MotorBridge.resetInjectionTrace()
        startTraceStreaming()
        let bundleIDs = MotorBridge.installedFreeFireBundleIDs()
        patchLog.append("🎯 Lojë e gjetur: \(bundleIDs.joined(separator: ", "))")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let local = MotorBridge.applyPatchFile(fileName, bundleIDs: bundleIDs)
            let trace = MotorBridge.injectionTrace()
            let patched = local["patched"] as? [String] ?? []
            let localErrors = local["errors"] as? [String] ?? []
            let paths = local["paths"] as? [String] ?? []
            let error = local["error"] as? String

            DispatchQueue.main.async {
                guard let self else { return }
                self.patchInFlight = false
                self.stopTraceStreaming()
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

    private func restorePatchWithFallback(fileName: String, completion: @escaping (Bool) -> Void) {
        patchInFlight = true
        MotorBridge.resetInjectionTrace()
        startTraceStreaming()
        let bundleIDs = MotorBridge.installedFreeFireBundleIDs()
        patchLog.append("🎯 Rikthim për: \(bundleIDs.joined(separator: ", "))")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let local = MotorBridge.restorePatchFile(fileName, bundleIDs: bundleIDs)
            let trace = MotorBridge.injectionTrace()
            let restored = local["restored"] as? [String] ?? []
            let localErrors = local["errors"] as? [String] ?? []
            let error = local["error"] as? String

            DispatchQueue.main.async {
                guard let self else { return }
                self.patchInFlight = false
                self.stopTraceStreaming()
                if restored.isEmpty {
                    if let error { self.patchLog.append("⚠️ \(error)") }
                    for line in localErrors.prefix(6) { self.patchLog.append("   \(line)") }
                    let tail = trace.split(separator: "\n").suffix(8)
                    if !tail.isEmpty {
                        self.patchLog.append("ℹ️ Gjurma e fundit:")
                        for line in tail { self.patchLog.append("   \(line)") }
                    }
                    completion(false)
                    return
                }
                self.patchLog.append("✅ Origjinali u kthye: \(restored.joined(separator: ", "))")
                completion(true)
            }
        }
    }

    /// The two aim cards share one destination (`cache_res`). Restoring the
    /// original also removed the other card's variant, so write it back alone.
    private func reapplyRemainingAim(after name: String) {
        let remaining: String
        let package: String
        switch name {
        case "AIM DRAG":
            guard aimPeitoEnabled else { return }
            remaining = "AIM PECHO"
            package = "aimtorso_cache"
        case "AIM PECHO":
            guard aimbotDragEnabled else { return }
            remaining = "AIM DRAG"
            package = "aimneck_cache"
        default:
            return
        }
        patchLog.append("⏳ \(remaining): duke rikthyer variantin e vetëm…")
        applyPatchWithFallback(fileName: package) { [weak self] success in
            guard let self else { return }
            guard success else {
                self.setFeature(remaining, enabled: false)
                self.patchLog.append("⚠️ \(remaining): variant i vetëm nuk u shkrua; karta mbeti e fikur.")
                return
            }
            self.patchLog.append("✅ \(remaining) mbetet aktiv (\(package)).")
        }
    }
}
