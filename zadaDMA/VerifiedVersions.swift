import Foundation

/// Build lists shown in Ajustes → Versiones verificadas (exactly as the
/// reference screenshots) plus the real compatibility check.
enum VerifiedVersions {
    static let legacyGroups = ["iOS 17", "iOS 18", "iOS 26"]

    static let exactBuilds: [String: Int] = [
        "iOS 17": 11,
        "iOS 18": 10,
        "iOS 26": 12,
        "iOS 27": 24
    ]

    static let ios27Groups: [(title: String, builds: [String])] = [
        ("iOS 27.0", [
            "24A5355q", "24A5370h", "24A5380h", "24A5390f", "24A5408d",
            "24A5418b", "24A5424a", "24A5430a", "24A435", "24A437"
        ]),
        ("iOS 27.0.1", ["24A446"]),
        ("iOS 27.2", ["24B5084k", "24B5089g", "24B119"]),
        ("iOS 27.2.1", ["24B156", "24B91034"]),
        ("iOS 27.3", ["24C5037i"])
    ]

    /// True when the device's iOS version + build appear in the verified lists.
    static func isCompatible(version: String, build: String) -> Bool {
        let parts = version.split(separator: ".").map(String.init)
        guard let first = parts.first, let major = Int(first) else { return false }
        if major != 27 {
            return [17, 18, 26].contains(major)
        }
        let minor = parts.count > 1 ? parts[1] : "0"
        let key = "iOS 27.\(minor)"
        guard let builds = ios27Groups.first(where: { $0.title == key })?.builds else { return false }
        return !build.isEmpty && builds.contains(build)
    }
}
