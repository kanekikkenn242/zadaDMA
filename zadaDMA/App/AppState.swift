import Foundation
import Combine

enum PairingPhase: Equatable {
    case idle
    case connecting
    case ready(String)
    case failed(String)
}

/// Persisted pairing settings plus the live state the dashboard reads.
@MainActor
final class AppState: ObservableObject {
    static let freeFireBundle = "com.dts.freefireth"
    static let freeFireMaxBundle = "com.dts.freefiremax"

    @Published var pairingFilePath: String
    @Published var host: String
    @Published var portText: String
    @Published var pin: String
    @Published var bundleIdentifier: String
    @Published var phase: PairingPhase = .idle
    @Published var installedFeatures: Set<String> = []
    @Published var busyFeature: String?

    let log = AppLog()

    private let defaults = UserDefaults.standard

    init() {
        pairingFilePath = defaults.string(forKey: "pairing.path") ?? ""
        host = defaults.string(forKey: "pairing.host") ?? "127.0.0.1"
        portText = defaults.string(forKey: "pairing.port") ?? "49152"
        pin = defaults.string(forKey: "pairing.pin") ?? "000000"
        bundleIdentifier = defaults.string(forKey: "game.bundle") ?? AppState.freeFireBundle
        installedFeatures = Set(defaults.stringArray(forKey: "features.installed") ?? [])
    }

    var port: UInt16? {
        guard let value = UInt16(portText.trimmingCharacters(in: .whitespaces)), value > 0 else {
            return nil
        }
        return value
    }

    var pairingReady: Bool {
        !pairingFilePath.isEmpty && FileManager.default.fileExists(atPath: pairingFilePath) && port != nil
    }

    var settings: PairingSettings {
        PairingSettings(pairingPath: pairingFilePath, host: host, port: port ?? 0, pin: pin)
    }

    func persist() {
        defaults.set(pairingFilePath, forKey: "pairing.path")
        defaults.set(host, forKey: "pairing.host")
        defaults.set(portText, forKey: "pairing.port")
        defaults.set(pin, forKey: "pairing.pin")
        defaults.set(bundleIdentifier, forKey: "game.bundle")
        defaults.set(Array(installedFeatures), forKey: "features.installed")
    }

    func markInstalled(_ featureID: String, _ installed: Bool) {
        if installed {
            installedFeatures.insert(featureID)
        } else {
            installedFeatures.remove(featureID)
        }
        persist()
    }
}

struct PairingSettings {
    let pairingPath: String
    let host: String
    let port: UInt16
    let pin: String
}
