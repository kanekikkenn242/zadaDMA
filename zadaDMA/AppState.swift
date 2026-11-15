import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var phase: String = "dashboard" // Hapet direkt ne dashboard
    @Published var licenseKey: String = "ZADADMA-VIP"
    @Published var timeRemaining: String = "28d 23:59:37"
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // Funksionet (si ne X)
    @Published var hsCabeca = false
    @Published var hsAlto = false
    @Published var hsPeito = false
    @Published var antennaMao = false
    @Published var aimbotEsp = false
    @Published var hologram = false
    @Published var skin = false
    
    // Statusi i injektimit
    @Published var injectionName: String? = nil
    @Published var injectionStep = 0
    @Published var injectionSuccess = false
    @Published var injectionError: String? = nil

    init() {
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
        _ = MotorBridge.bootstrap()
    }

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
