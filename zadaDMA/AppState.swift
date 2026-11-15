import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case booting, license, dashboard, blocked(String) }
    @Published var phase: Phase = .booting
    
    // Të dhënat e Profilit
    @Published var licenseKey: String = ""
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

    // Variablat që i kërkojnë skedarët e tjerë
    @Published var containers: [String] = []
    @Published var sandboxReady = false
    @Published var log: [String] = []

    func boot() {
        _ = MotorBridge.bootstrap()
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.phase = .license
        }
    }

    func unlockApp(key: String) -> Bool {
        if key.uppercased() == "ZADADMA2026" {
            self.licenseKey = key.uppercased()
            self.enterDashboard()
            return true
        }
        return false
    }

    func enterDashboard() {
        self.phase = .dashboard
        preload()
    }

    func preload() {
        MotorBridge.ensureSandbox { [weak self] ok, _ in
            Task { @MainActor in
                self?.sandboxReady = ok
                if ok { self?.containers = (MotorBridge.appContainers() as? [String]) ?? [] }
                self?.log.append("Sandbox ready: \(ok)")
            }
        }
    }

    func apply(packageData: Data, bundleID: String, pass: String) {
        // KETU E RREGULLOVA: perdorim packageData ne vend te data
        let _ = MotorBridge.applyPackageData(packageData, passphrase: pass, bundleID: bundleID)
        self.log.append("Applied package to \(bundleID)")
    }

    func applyPatch(filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: "3105") else { 
            self.log.append("[-] Missing \(filename).3105")
            return 
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let ok = MotorBridge.applyPackageData(data, passphrase: "shared-server-secret", bundleID: "com.dts.freefireth")
            self.log.append("Patch \(filename): \(ok ? "OK" : "Failed")")
        } catch {
            self.log.append("Error: \(error.localizedDescription)")
        }
    }

    func startInjection(featureName: String, isOn: Bool, patchName: String? = nil) {
        guard isOn else { return }
        self.activeInjectionName = featureName
        self.injectionStep = 1
        self.injectionSuccess = false
        
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
    }
}
