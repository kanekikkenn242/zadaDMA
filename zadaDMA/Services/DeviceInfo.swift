import Foundation
import SwiftUI
import sys.utsname

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
        return ("Compatível", .green)
    }
}
