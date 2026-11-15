import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case booting, license, dashboard, blocked(String) }
    @Published var phase: Phase = .dashboard // Hapet direkt
    
    // Të dhënat e Profilit
    @Published var licenseKey: String = "ZADADMA-VIP"
    @Published var expiryDate: String = "2026-09-22T17:22:42.570807"
    @Published var timeRemaining: String = "28d 23:59:37"
    
    // Statusi i pajisjes
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // Funksionet e reja
    @Published var hsCabecaEnabled = false
    @Published var hsCabeca90Enabled = false
    @Published var hsAltoEnabled = false
    @Published var hsPeitoEnabled = false
    @Published var antennaMaoEnabled = false
    
    @Published var painelEnabled = false
    @Published var aimbotEspEnabled = false
    @Published var fps144Enabled = false
    
    @Published var activeInjectionName: String? = nil
    @Published var injectionStep: Int = 0
    @Published var injectionSuccess: Bool = false
    @Published var injectionError: String? = nil

    // Variablat që i kërkojnë skedarët e vjetër (që të mos bejne error build)
    @Published var containers: [String] = []
    @Published var sandboxReady = false
    @Published var log: [String] = []

    init() {
        boot()
    }

    func boot() {
        _ = MotorBridge.bootstrap()
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
    }

    func unlockApp(key: String) -> Bool { return true }
    func enterDashboard() { self.phase = .dashboard; preload() }

    func preload() {
        MotorBridge.ensureSandbox { [weak self] ok, _ in
            Task { @MainActor in
                self?.sandboxReady = ok
                if ok { self?.containers = (MotorBridge.appContainers() as? [String]) ?? [] }
            }
        }
    }

    func apply(packageData: Data, bundleID: String, pass: String) {
        let _ = MotorBridge.applyPackageData(packageData, passphrase: pass, bundleID: bundleID)
    }

    func applyPatch(filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: "3105") else { return }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let _ = MotorBridge.applyPackageData(data, passphrase: "shared-server-secret", bundleID: "com.dts.freefireth")
        } catch {}
    }

    func startInjection(featureName: String, isOn: Bool, patchName: String? = nil) {
        guard isOn else { return }
        self.activeInjectionName = featureName
        self.injectionStep = 1
        self.injectionSuccess = false
        self.injectionError = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.injectionStep = 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { self.injectionStep = 3 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { self.injectionStep = 4 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            if let patch = patchName { self.applyPatch(filename: patch) }
            self.injectionSuccess = true
        }
    }
    
    func closeInjection() {
        self.activeInjectionName = nil
        self.injectionStep = 0
        self.injectionSuccess = false
        self.injectionError = nil
    }
}
