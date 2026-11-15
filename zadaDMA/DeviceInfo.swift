import Foundation
import UIKit

struct DeviceInfo {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        return machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    var systemVersion: String {
        return "\(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemVersionString.components(separatedBy: " ").last ?? ""))"
    }
    
    var buildVersion: String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }
}
