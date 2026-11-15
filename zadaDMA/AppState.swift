import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum Phase { case booting, license, dashboard, blocked(String) }
    @Published var phase: Phase = .booting
    @Published var products: [Product] = []
    @Published var containers: [String] = []
    @Published var log: [String] = []
    
    // Të dhënat e shfaqura në Profil
    @Published var licenseKey: String = ""
    @Published var udid: String = "00008140-000A18D60102801C"
    @Published var timeRemaining: String = "22h 23m"
    
    // Statusi i modifikimeve
    @Published var isAimChestEnabled = false
    @Published var isAimDragEnabled = false
    @Published var sandboxReady = false

    func boot() {
        if !MotorBridge.bootstrap() {
            log.append("Anti-tamper failed")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.phase = .license
        }
    }

    func unlockApp(key: String) {
        self.licenseKey = key.uppercased()
        self.enterDashboard()
    }

    // Ktheu funksionin që e kërkon OnboardingView
    func enterDashboard() {
        self.phase = .dashboard
        preload()
    }

    func preload() {
        MotorBridge.ensureSandbox { [weak self] ok, _ in
            Task { @MainActor in
                self?.sandboxReady = ok
                if ok { self?.containers = (MotorBridge.appContainers() as? [String]) ?? [] }
                self?.log.append("Sandbox: \(ok)")
            }
        }
    }
    
    func toggleAimChest(_ isOn: Bool) {
        isAimChestEnabled = isOn
        guard let path = Bundle.main.path(forResource: "aimdrag_neck", ofType: "3105") else {
            log.append("[-] Skedari .3105 mungon në bundle")
            return
        }
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            if isOn {
                let ok = MotorBridge.applyPackageData(data, passphrase: "shared-server-secret", bundleID: "com.dts.freefireth")
                log.append("Patch ON: \(ok ? "Sukses" : "Dështoi")")
            } else {
                log.append("Patch OFF")
            }
        } catch {
            log.append("Gabim: \(error.localizedDescription)")
        }
    }

    // Ktheu funksionin që e kërkon ProductActivationCoordinator
    func apply(packageData: Data, bundleID: String, pass: String) {
        let ok = MotorBridge.applyPackageData(packageData, passphrase: pass, bundleID: bundleID)
        log.append("patch \(bundleID): \(ok ? "ok" : "fail")")
    }
}

struct Product: Identifiable { 
    let id: String
    let name: String
    let slug: String
    let category: String 
}
