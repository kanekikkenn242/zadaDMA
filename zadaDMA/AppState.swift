import SwiftUI

@MainActor
final class AppState: ObservableObject {
    // Statusi i përgjithshëm
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
            // Simulim i procesit te injektimit (mund te lidhet me MotorBridge)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.isProcessing = false
            }
        }
    }
}
