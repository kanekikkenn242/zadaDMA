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
        UIDevice.current.systemVersion
    }
    var buildVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }
    var buildNumber: String {
        let raw = ProcessInfo.processInfo.operatingSystemVersionString
        guard let open = raw.range(of: "(Build ") else { return "" }
        let tail = raw[open.upperBound...]
        guard let close = tail.range(of: ")") else { return "" }
        return String(tail[..<close.lowerBound])
    }
}
