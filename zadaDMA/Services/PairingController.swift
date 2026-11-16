import Foundation
import UIKit
import Combine
import UniformTypeIdentifiers

/// Pairing + file injection for iOS 27.
///
/// The app is a *pairable host*: iOS discovers it through
/// `_remotepairing-pairable-host._tcp`, the user types the PIN shown here,
/// and iOS writes an RPPairing file. File injection then opens the
/// `_remotepairing._tcp` tunnel and writes through House Arrest/AFC.
final class PairingController: ObservableObject {
    static let shared = PairingController()

    @Published var hasPairingFile: Bool = false
    @Published var pairingStatus: String = "Idle"
    @Published var currentPin: String = ""
    @Published var isPairing: Bool = false

    private let hostName = "zadaDMA"
    private let hostModel = "Mac17,7"

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var pairingFilePath: String {
        documentsURL.appendingPathComponent("rppairing.plist").path
    }

    private var legacyPairingFilePath: String {
        documentsURL.appendingPathComponent("pairing.plist").path
    }

    init() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
        if hasPairingFile {
            pairingStatus = "Paired (RPPairing)"
        }
    }

    // MARK: - Device-initiated pairing

    func startPairing(completion: @escaping (Bool) -> Void) {
        guard !isPairing else {
            completion(false)
            return
        }
        isPairing = true
        currentPin = ""
        pairingStatus = "Duke hapur pairing host…"

        IdeviceBridge.shared().startPairableHost(
            withName: hostName,
            model: hostModel,
            port: 0,
            pairingFilePath: pairingFilePath,
            readyBlock: { [weak self] identifier, port in
                guard let self else { return }
                self.pairingStatus = "Host aktiv (port \(port)). Hap Settings → Privacy & Security → Developer Mode → Pair with \"\(self.hostName)\"."
                print("[Pairing] ready identifier=\(identifier) port=\(port)")
            },
            pinBlock: { [weak self] pin in
                guard let self else { return }
                self.currentPin = pin
                self.pairingStatus = "PIN \(pin) — shkruaje në iPhone."
                print("[Pairing] PIN \(pin)")
            },
            completion: { [weak self] success, message in
                guard let self else { return }
                self.isPairing = false
                self.hasPairingFile = FileManager.default.fileExists(atPath: self.pairingFilePath)
                if success {
                    self.currentPin = ""
                    self.pairingStatus = "Paired (RPPairing)"
                } else {
                    self.pairingStatus = message.isEmpty ? "Pairing dështoi" : message
                }
                completion(success)
            }
        )
    }

    func stopPairing() {
        IdeviceBridge.shared().cancelPairableHost()
        isPairing = false
        currentPin = ""
        pairingStatus = "Pairing cancelled"
    }

    func reloadPairingFile() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
        if hasPairingFile {
            pairingStatus = "Paired (RPPairing)"
        }
    }

    // MARK: - Import / export of the RPPairing file

    func importPairingFile(url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else {
                pairingStatus = "Import failed: file empty"
                return false
            }
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any],
                  dict["public_key"] is Data,
                  dict["private_key"] is Data else {
                pairingStatus = "Ky file nuk është RPPairing. Përdor Start Pairing, jo pairing.plist nga PC."
                return false
            }
            let dest = URL(fileURLWithPath: pairingFilePath)
            if FileManager.default.fileExists(atPath: pairingFilePath) {
                try FileManager.default.removeItem(at: dest)
            }
            try data.write(to: dest, options: .atomic)
            hasPairingFile = true
            pairingStatus = "RPPairing file imported"
            return true
        } catch {
            pairingStatus = "Import failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Tunnel + AFC write

    func injectFile(localPath: String,
                    remotePath: String,
                    bundleID: String = "com.dts.freefireth",
                    completion: @escaping (Bool, String) -> Void) {
        guard hasPairingFile else {
            completion(false, "Pairing file mungon. Bëj Start Pairing.")
            return
        }
        pairingStatus = "Duke u lidhur me iPhone…"
        IdeviceBridge.shared().writeFile(
            atPath: localPath,
            bundleID: bundleID,
            remotePath: remotePath,
            pairingFilePath: pairingFilePath,
            hostname: hostName,
            completion: { [weak self] success, message in
                self?.pairingStatus = message
                print("[Pairing] AFC \(success ? "OK" : "FAIL"): \(message)")
                completion(success, message)
            }
        )
    }
}
