import Foundation
import SwiftUI

enum DeviceInfo {
    static func getHardwareModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    static func getIOSVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    static func isExploitCompatible() -> (status: String, color: Color) {
        let version = UIDevice.current.systemVersion
        let model = getHardwareModel()
        if model.hasPrefix("iPhone9,") || model.hasPrefix("iPhone8,") {
            if version.hasPrefix("15.") || version.hasPrefix("14.") || version.hasPrefix("13.") {
                return ("Compatible", .green)
            }
        }
        if version.hasPrefix("16.") || version.hasPrefix("17.") {
            return ("No compatible", .red)
        }
        return ("Desconocido", .orange)
    }
}
