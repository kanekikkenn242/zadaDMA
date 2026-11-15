import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = false
    @Published var isActivated: Bool = false
    @Published var licenseKey: String = ""
    
    // Të dhënat e Pajisjes
    @Published var deviceModel: String = ""
    @Published var deviceiOS: String = ""
    
    // Funksionet Free Fire
    @Published var aimPeitoEnabled: Bool = false
    @Published var aimbotDragEnabled: Bool = false
    @Published var isProcessing: Bool = false
    
    init() {
        self.deviceModel = DeviceInfo.getHardwareModel()
        self.deviceiOS = DeviceInfo.getIOSVersion()
    }
    
    func toggleAimPeito(_ isOn: Bool) {
        aimPeitoEnabled = isOn
        if isOn {
            isProcessing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isProcessing = false
            }
        }
    }
    
    // Funksioni që kërkon ProductActivationCoordinator (i vjetër)
    func apply(packageData: Data, bundleID: String, pass: String) {
        // Bosh, thjesht që të mos dështojë build-i
    }
}
