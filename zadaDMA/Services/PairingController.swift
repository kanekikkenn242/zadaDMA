import Foundation
import UIKit
import Combine
import UniformTypeIdentifiers
import BackgroundTasks
import UserNotifications

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
    /// iOS refused the continued-processing task: only ~30s of background time remain.
    @Published var backgroundLimited: Bool = false

    private let hostName = "zadaDMA"
    private let hostModel = "Mac17,7"

    private var graceTask: UIBackgroundTaskIdentifier = .invalid
    private var continuedTask: AnyObject?          // BGContinuedProcessingTask (iOS 26+)
    private var registeredTaskIdentifier: String?
    private var lastNotifiedPin: String?
    private var cancelReason: String?

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var pairingFilePath: String {
        documentsURL.appendingPathComponent("rppairing.plist").path
    }

    /// Marks `rppairing.plist` as produced by this build. Pairing files written
    /// before the uppercase-identifier fix cannot pass pair-verify, so they must
    /// never be used for injection.
    private var pairingReadyPath: String {
        documentsURL.appendingPathComponent("rppairing.ready").path
    }

    private let pairingFileVersion = 2

    private func plistDictionary(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }

    private var isPairingReady: Bool {
        guard FileManager.default.fileExists(atPath: pairingFilePath),
              FileManager.default.fileExists(atPath: pairingReadyPath),
              let pairing = plistDictionary(at: pairingFilePath),
              let marker = plistDictionary(at: pairingReadyPath),
              let version = marker["version"] as? Int,
              version == pairingFileVersion,
              let markerIdentifier = marker["identifier"] as? String,
              !markerIdentifier.isEmpty,
              markerIdentifier == markerIdentifier.uppercased(),
              let fileIdentifier = pairing["identifier"] as? String,
              fileIdentifier == markerIdentifier else {
            return false
        }
        return true
    }

    @discardableResult
    private func writeReadyMarkerFromPairingFile() -> Bool {
        guard let pairing = plistDictionary(at: pairingFilePath),
              let identifier = pairing["identifier"] as? String,
              !identifier.isEmpty,
              identifier == identifier.uppercased() else {
            return false
        }
        let marker: [String: Any] = [
            "version": pairingFileVersion,
            "identifier": identifier,
        ]
        guard let data = try? PropertyListSerialization.data(fromPropertyList: marker, format: .xml, options: 0) else {
            return false
        }
        do {
            try data.write(to: URL(fileURLWithPath: pairingReadyPath), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func clearPairingFiles() {
        try? FileManager.default.removeItem(atPath: pairingFilePath)
        try? FileManager.default.removeItem(atPath: pairingReadyPath)
        hasPairingFile = false
    }

    init() {
        hasPairingFile = isPairingReady
        if hasPairingFile {
            pairingStatus = "Paired (RPPairing)"
        } else if FileManager.default.fileExists(atPath: pairingFilePath) {
            pairingStatus = "Pairing i vjetër — bëj Start Pairing përsëri."
        }
    }

    // MARK: - Device-initiated pairing

    func startPairing(completion: @escaping (Bool) -> Void) {
        guard !isPairing else {
            completion(false)
            return
        }
        isPairing = true
        backgroundLimited = false
        cancelReason = nil
        lastNotifiedPin = nil
        currentPin = ""
        clearPairingFiles()
        pairingStatus = "Duke hapur pairing host…"

        requestNotificationPermission()
        beginBackgroundExecution()

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
                self.pairingStatus = "PIN \(pin) — shkruaje në Settings."
                print("[Pairing] PIN \(pin)")
#if compiler(>=6.2)
                if #available(iOS 26.0, *), let task = self.continuedTask as? BGContinuedProcessingTask {
                    task.updateTitle("Kodi \(pin)", subtitle: "Shkruaje në Settings për t'u çiftuar me zadaDMA")
                    task.progress.completedUnitCount = 1
                }
#endif
                if UIApplication.shared.applicationState != .active {
                    self.notifyPin(pin)
                }
            },
            completion: { [weak self] success, message in
                guard let self else { return }
                self.isPairing = false
                if success {
                    _ = self.writeReadyMarkerFromPairingFile()
                }
                self.hasPairingFile = self.isPairingReady
                self.endBackgroundExecution(success: success)
                if let reason = self.cancelReason {
                    self.cancelReason = nil
                    self.pairingStatus = reason
                } else if success && self.hasPairingFile {
                    self.currentPin = ""
                    self.pairingStatus = "Paired (RPPairing)"
                } else if success {
                    self.currentPin = ""
                    self.pairingStatus = "Pairing u krye, por pairing file nuk u verifikua. Bëj Start Pairing përsëri."
                } else {
                    self.pairingStatus = message.isEmpty ? "Pairing dështoi" : message
                }
                completion(success)
            }
        )
    }

    func stopPairing() {
        guard isPairing else { return }
        cancelReason = "Pairing cancelled"
        pairingStatus = "Duke ndalur pairing…"
        currentPin = ""
        IdeviceBridge.shared().cancelPairableHost()
    }

    func reloadPairingFile() {
        if FileManager.default.fileExists(atPath: pairingFilePath) {
            _ = writeReadyMarkerFromPairingFile()
        }
        hasPairingFile = isPairingReady
        if hasPairingFile {
            pairingStatus = "Paired (RPPairing)"
        } else if FileManager.default.fileExists(atPath: pairingFilePath) {
            pairingStatus = "Pairing i vjetër — bëj Start Pairing përsëri."
        }
    }

    // MARK: - Staying alive while the user is in Settings

    /// Called from the app entry point so BGTaskScheduler has the handler before launch ends.
    func prepareBackgroundTask() {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            _ = registerContinuedProcessingIfNeeded()
        }
#endif
    }

    private func beginBackgroundExecution() {
        endBackgroundExecution(success: false)
        graceTask = UIApplication.shared.beginBackgroundTask(withName: "zadaDMA pairing") { [weak self] in
            DispatchQueue.main.async { self?.backgroundExpired() }
        }
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            submitContinuedProcessing()
        } else {
            backgroundLimited = true
        }
#else
        backgroundLimited = true
#endif
    }

    private func endBackgroundExecution(success: Bool) {
#if compiler(>=6.2)
        if #available(iOS 26.0, *), let task = continuedTask as? BGContinuedProcessingTask {
            task.progress.completedUnitCount = task.progress.totalUnitCount
            task.setTaskCompleted(success: success)
        }
#endif
        continuedTask = nil
        if graceTask != .invalid {
            UIApplication.shared.endBackgroundTask(graceTask)
            graceTask = .invalid
        }
    }

    private func backgroundExpired() {
        guard isPairing else { return }
        cancelReason = "iOS e ndaloi app-in në background para se pairing të përfundonte. Provo përsëri dhe shko direkt në Settings."
        pairingStatus = cancelReason ?? "Pairing cancelled"
        currentPin = ""
        endBackgroundExecution(success: false)
        IdeviceBridge.shared().cancelPairableHost()
    }

    private var continuedTaskIdentifier: String? {
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String] ?? []
        guard let wildcard = permitted.first(where: { $0.hasSuffix(".pairing.*") }) else { return nil }
        return String(wildcard.dropLast()) + "session"
    }

#if compiler(>=6.2)
    @available(iOS 26.0, *)
    private func registerContinuedProcessingIfNeeded() -> String? {
        guard let identifier = continuedTaskIdentifier else {
            backgroundLimited = true
            print("[Pairing] BGTaskSchedulerPermittedIdentifiers mungon")
            return nil
        }
        if registeredTaskIdentifier == identifier { return identifier }
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier,
                                                         using: nil) { [weak self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            DispatchQueue.main.async {
                self?.attachContinuedTask(task)
            }
        }
        guard registered else {
            backgroundLimited = true
            print("[Pairing] BG register refused: \(identifier)")
            return nil
        }
        registeredTaskIdentifier = identifier
        return identifier
    }

    @available(iOS 26.0, *)
    private func submitContinuedProcessing() {
        guard let identifier = registerContinuedProcessingIfNeeded() else { return }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier,
                                                       title: "Pairing me zadaDMA",
                                                       subtitle: "Settings › Privacy & Security › Developer Mode")
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
            print("[Pairing] BG continued-processing submitted")
        } catch {
            backgroundLimited = true
            print("[Pairing] BG continued-processing refused: \(error)")
        }
    }

    @available(iOS 26.0, *)
    private func attachContinuedTask(_ task: BGContinuedProcessingTask) {
        guard isPairing else {
            task.setTaskCompleted(success: false)
            return
        }
        continuedTask = task
        task.progress.totalUnitCount = 2
        if !currentPin.isEmpty {
            task.updateTitle("Kodi \(currentPin)", subtitle: "Shkruaje në Settings për t'u çiftuar me zadaDMA")
            task.progress.completedUnitCount = 1
        }
        task.expirationHandler = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.continuedTask = nil
                self.backgroundExpired()
            }
        }
        print("[Pairing] BG continued-processing running")
    }
#endif

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyPin(_ pin: String) {
        guard lastNotifiedPin != pin else { return }
        lastNotifiedPin = pin
        let content = UNMutableNotificationContent()
        content.title = "Kodi i pairing: \(pin)"
        content.body = "Shkruaje në Settings › Privacy & Security › Developer Mode për t'u çiftuar me zadaDMA."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "zadaDMA.pairing.pin",
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
            guard writeReadyMarkerFromPairingFile() else {
                try? FileManager.default.removeItem(at: dest)
                try? FileManager.default.removeItem(atPath: pairingReadyPath)
                hasPairingFile = false
                pairingStatus = "RPPairing file i vjetër (identifier mungon ose është lowercase). Bëj Start Pairing."
                return false
            }
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
        let ready = isPairingReady
        hasPairingFile = ready
        guard ready else {
            completion(false, "Pairing file mungon ose është i vjetër. Bëj Start Pairing përsëri.")
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
