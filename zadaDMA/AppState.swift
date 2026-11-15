import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // 1. Variablat që kërkon Dashboard-i i Ri
    @Published var licenseKey: String = "ZADADMA-VIP"
    @Published var timeRemaining: String = "28d 23:59:37"
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // 2. Toggle-at e reja (si tek X)
    @Published var hsCabeca = false
    @Published var hsAlto = false
    @Published var hsPeito = false
    @Published var antennaMao = false
    @Published var aimbotEsp = false
    @Published var hologram = false
    @Published var skin = false
    
    // 3. Statusi i Injektimit
    @Published var injectionName: String? = nil
    @Published var injectionStep = 0
    @Published var injectionSuccess = false
    @Published var injectionError: String? = nil

    // 4. Variablat që i kërkojnë skedarët e vjetër (SettingsView, FileBrowserView)
    @Published var containers: [String] = []
    @Published var sandboxReady = false
    @Published var log: [String] = []

    init() {
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
        _ = MotorBridge.bootstrap()
    }

    // 5. Funksionet që i kërkon LicenseGate dhe Onboarding
    func unlockApp(key: String) -> Bool {
        return true // E lemë true që të kalojë pa problem
    }
    
    func enterDashboard() {
        // Bosh, pasi ne hapemi direkt në Dashboard
    }

    // 6. Funksioni që i kërkon ProductActivationCoordinator
    func apply(packageData: Data, bundleID: String, pass: String) {
        let _ = MotorBridge.applyPackageData(packageData, passphrase: pass, bundleID: bundleID)
    }

    // 7. Funksioni i Injektimit
    func startInjection(name: String, patchFile: String) {
        injectionName = name
        injectionStep = 1
        injectionSuccess = false
        injectionError = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.injectionStep = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.injectionStep = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.injectionStep = 4
            Task {
                let path = Bundle.main.path(forResource: patchFile, ofType: "3105")
                if let p = path, let data = try? Data(contentsOf: URL(fileURLWithPath: p)) {
                    let ok = MotorBridge.applyPackageData(data, passphrase: "shared-server-secret", bundleID: "com.dts.freefireth")
                    await MainActor.run {
                        if ok { self.injectionSuccess = true }
                        else { self.injectionError = "Sandbox escape falhou. iOS 27 bloqueia o exploit."; self.injectionSuccess = false }
                    }
                } else {
                    await MainActor.run { self.injectionError = "Skedari mungon në bundle."; self.injectionSuccess = false }
                }
            }
        }
    }
}
