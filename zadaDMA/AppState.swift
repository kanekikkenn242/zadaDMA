import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var phase: String = "dashboard"
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    @Published var kernelActive: Bool = false
    
    // Funksionet
    @Published var hsCabeca = false
    @Published var hsCabeca90 = false
    @Published var aimbotEsp = false
    
    // Statusi i Injektimit
    @Published var injectionName: String? = nil
    @Published var injectionStep = 0
    @Published var injectionSuccess = false
    @Published var injectionError: String? = nil

    init() {
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
        
        // Provojmë të nisim kernel exploit në sfond
        DispatchQueue.global(qos: .background).async {
            let ok = MotorBridge.bootstrap()
            DispatchQueue.main.async {
                self.kernelActive = ok
            }
        }
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
                let ok = MotorBridge.applyPatch(patchFile)
                await MainActor.run {
                    if ok {
                        self.injectionSuccess = true
                    } else {
                        self.injectionError = "Sandbox escape falhou. iOS 27 bloqueia o kfd."
                        self.injectionSuccess = false
                    }
                }
            }
        }
    }
}
