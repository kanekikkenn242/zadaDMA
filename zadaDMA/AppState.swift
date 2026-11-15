import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case booting, license, dashboard }
    @Published var phase: Phase = .booting
    
    @Published var licenseKey: String = ""
    @Published var expiryDate: String = "2026-09-22T17:22:42.570807"
    @Published var timeRemaining: String = "28d 23:59:37"
    
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // Toggle-at (Funções)
    @Published var hsCabecaEnabled = false
    @Published var hsCabeca90Enabled = false  // I RI: Aim Neck 90%
    @Published var hsAltoEnabled = false
    @Published var hsPeitoEnabled = false
    @Published var antennaMaoEnabled = false
    
    // Toggle-at (Partidas)
    @Published var painelEnabled = false
    @Published var aimbotEspEnabled = false
    @Published var fps144Enabled = false
    
    @Published var activeInjectionName: String? = nil
    @Published var injectionStep: Int = 0
    @Published var injectionSuccess: Bool = false

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
            self.phase = .dashboard
            return true
        }
        return false
    }

    // Funksioni që aplikon patch-in në heshtje
    func applyPatch(filename: String) {
        guard let path = Bundle.main.path(forResource: filename, ofType: "3105") else {
            print("[-] Skedari \(filename).3105 mungon ne bundle")
            return
        }
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let _ = MotorBridge.applyPackageData(data, passphrase: "shared-server-secret", bundleID: "com.dts.freefireth")
        } catch {
            print("[-] Gabim: \(error.localizedDescription)")
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
            if let patch = patchName {
                self.applyPatch(filename: patch)
            }
            self.injectionSuccess = true
        }
    }
    
    func closeInjection() {
        self.activeInjectionName = nil
        self.injectionStep = 0
        self.injectionSuccess = false
    }
}
