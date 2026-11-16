import Foundation
import UIKit
import Combine
import Darwin

class PairingController: ObservableObject {
    static let shared = PairingController()

    @Published var hasPairingFile: Bool = false
    @Published var pairingStatus: String = "Idle"
    @Published var currentPin: String = ""

    private typealias ConnectFn       = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UInt16) -> Int32
    private typealias WriteFn         = @convention(c) (Int32, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias CloseFn         = @convention(c) (Int32) -> Int32
    private typealias StartPairingFn  = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias GeneratePinFn   = @convention(c) (UnsafeMutablePointer<CChar>, UInt32) -> Int32
    private typealias GetContainerFn  = @convention(c) (UnsafePointer<CChar>,
                                                       UnsafePointer<CChar>,
                                                       UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32

    private var connectFn: ConnectFn?
    private var writeFn: WriteFn?
    private var closeFn: CloseFn?
    private var startPairingFn: StartPairingFn?
    private var generatePinFn: GeneratePinFn?
    private var getContainerFn: GetContainerFn?

    private var pairingFilePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pairing.plist").path
    }

    init() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
        loadSymbols()
    }

    private func loadSymbols() {
        let rtld = UnsafeMutableRawPointer(bitPattern: -2)

        for name in ["idevice_afc_connect_with_pairing_file",
                     "idevice_connect_with_pairing_file",
                     "idevice_connect"] {
            if let ptr = dlsym(rtld, name) {
                connectFn = unsafeBitCast(ptr, to: ConnectFn.self)
                print("[Pairing] Connect: \(name)")
                break
            }
        }
        for name in ["idevice_afc_write", "idevice_write_file"] {
            if let ptr = dlsym(rtld, name) {
                writeFn = unsafeBitCast(ptr, to: WriteFn.self)
                print("[Pairing] Write: \(name)")
                break
            }
        }
        for name in ["idevice_afc_close", "idevice_close"] {
            if let ptr = dlsym(rtld, name) {
                closeFn = unsafeBitCast(ptr, to: CloseFn.self)
                print("[Pairing] Close: \(name)")
                break
            }
        }
        for name in ["idevice_start_pairing_host",
                     "idevice_rppairing_start_host",
                     "idevice_pairing_start"] {
            if let ptr = dlsym(rtld, name) {
                startPairingFn = unsafeBitCast(ptr, to: StartPairingFn.self)
                print("[Pairing] StartPairing: \(name)")
                break
            }
        }
        for name in ["zdma_generate_pin", "idevice_generate_pin"] {
            if let ptr = dlsym(rtld, name) {
                generatePinFn = unsafeBitCast(ptr, to: GeneratePinFn.self)
                print("[Pairing] GeneratePin: \(name)")
                break
            }
        }
        for name in ["idevice_house_arrest_get_container_path",
                     "idevice_get_app_container",
                     "idevice_afc_get_container_path"] {
            if let ptr = dlsym(rtld, name) {
                getContainerFn = unsafeBitCast(ptr, to: GetContainerFn.self)
                print("[Pairing] Container: \(name)")
                break
            }
        }
    }

    func generatePin() -> String {
        // 1) Provo funksionin Rust/idevice nese eshte i lidhur.
        if let generate = generatePinFn {
            var pinBuf = [CChar](repeating: 0, count: 7)
            let result = generate(&pinBuf, UInt32(pinBuf.count))
            if result == 0 {
                let pin = String(cString: pinBuf)
                if pin.count == 6, pin.allSatisfy({ $0.isNumber }) {
                    currentPin = pin
                    pairingStatus = "PIN ready"
                    return pin
                }
            }
            print("[-] generatePin fallback, result: \(String(describing: result))")
        }
        // 2) Fallback lokal: PIN 6-shifror, gjithmone funksionon.
        let pin = String(format: "%06d", Int.random(in: 0..<1000000))
        currentPin = pin
        pairingStatus = "PIN ready"
        return pin
    }

    func startPairing(pin: String, completion: @escaping (Bool) -> Void) {
        guard pin.count == 6, pin.allSatisfy({ $0.isNumber }) else {
            pairingStatus = "Invalid PIN"
            completion(false)
            return
        }
        guard let startPairing = startPairingFn else {
            print("[-] Funksioni i pairing nuk u gjet. Perdor manualisht PIN-in.")
            pairingStatus = "Manual pairing: Settings → Developer Mode"
            completion(false)
            return
        }
        pairingStatus = "Waiting for Developer Mode…"
        DispatchQueue.global(qos: .background).async {
            let result = pin.withCString { pp in
                self.pairingFilePath.withCString { fp in
                    startPairing(fp, pp)
                }
            }
            DispatchQueue.main.async {
                self.hasPairingFile = FileManager.default.fileExists(atPath: self.pairingFilePath)
                self.pairingStatus = result == 0 ? "Paired" : "Failed"
                completion(result == 0)
            }
        }
    }

    func stopPairing() {
        print("[Pairing] Stopped.")
    }

    func injectFile(localPath: String, remotePath: String) -> Bool {
        guard hasPairingFile, let connectC = connectFn, let writeC = writeFn else {
            print("[-] injectFile: funksionet ose pairing file mungon")
            return false
        }
        var client: Int32 = -1
        if let pp = pairingFilePath.cString(using: .utf8),
           let hp = "127.0.0.1".cString(using: .utf8) {
            client = connectC(pp, hp, 49152)
        }
        guard client >= 0 else { return false }

        let ok = localPath.withCString { lp -> Bool in
            remotePath.withCString { rp -> Bool in
                writeC(client, rp, lp) == 0
            }
        }
        if let closeC = closeFn { _ = closeC(client) }
        return ok
    }

    func getContainerPath(bundleID: String) -> String? {
        guard hasPairingFile, let getContainer = getContainerFn else {
            print("[-] getContainerPath: pairing ose funksion mungon")
            return nil
        }
        var outPath: UnsafeMutablePointer<CChar>? = nil
        if let pp = pairingFilePath.cString(using: .utf8),
           let bp = bundleID.cString(using: .utf8) {
            let result = getContainer(pp, bp, &outPath)
            if result == 0, let p = outPath {
                let path = String(cString: p)
                free(p)
                return path
            }
        }
        return nil
    }

    func reloadPairingFile() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
    }

    func importPairingFile(url: URL) -> Bool {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let dest = URL(fileURLWithPath: pairingFilePath)
            if FileManager.default.fileExists(atPath: pairingFilePath) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            hasPairingFile = true
            pairingStatus = "Pairing file imported"
            return true
        } catch {
            print("[-] Gabim: \(error)")
            pairingStatus = "Import failed"
            return false
        }
    }

    func writeAimFile(remoteDir: String, filename: String, localData: Data) -> Bool {
        guard hasPairingFile, let connectC = connectFn, let writeC = writeFn else {
            print("[-] writeAimFile: funksionet ose pairing file mungon")
            return false
        }
        var client: Int32 = -1
        if let pp = pairingFilePath.cString(using: .utf8),
           let hp = "127.0.0.1".cString(using: .utf8) {
            client = connectC(pp, hp, 49152)
        }
        guard client >= 0 else { return false }

        let fullRemote = "\(remoteDir)/\(filename)"
        var ok = false
        if let rp = fullRemote.cString(using: .utf8) {
            let rc: Int32 = localData.withUnsafeBytes { raw -> Int32 in
                guard let base = raw.baseAddress else { return -1 }
                return writeC(client, rp, base.assumingMemoryBound(to: CChar.self))
            }
            ok = rc == 0
        }
        if let closeC = closeFn { _ = closeC(client) }
        return ok
    }

    // NOTE: `Process` is macOS-only. Not available on iOS.
    func gitPush(to remoteURL: String, branch: String = "main",
                 completion: @escaping (Bool, String) -> Void) {
        guard hasPairingFile, let connectC = connectFn, let writeC = writeFn else {
            completion(false, "Pairing file or symbols missing")
            return
        }
        let pairingPath = pairingFilePath
        let closeC = closeFn

        DispatchQueue.global(qos: .background).async {
            var client: Int32 = -1
            if let pp = pairingPath.cString(using: .utf8),
               let hp = "127.0.0.1".cString(using: .utf8) {
                client = connectC(pp, hp, 49152)
            }
            guard client >= 0 else {
                DispatchQueue.main.async { completion(false, "Failed to connect") }
                return
            }
            defer { if let c = closeC { _ = c(client) } }

            for name in ["project.yml", "Info.plist", "Assets.car"] {
                let base = name.replacingOccurrences(of: ".plist", with: "")
                let type = name.hasSuffix(".plist") ? "plist" : nil
                guard let path = Bundle.main.path(forResource: base, ofType: type),
                      let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                      let rp = name.cString(using: .utf8) else { continue }
                _ = data.withUnsafeBytes { raw -> Int32 in
                    guard let b = raw.baseAddress else { return -1 }
                    return writeC(client, rp, b.assumingMemoryBound(to: CChar.self))
                }
            }
            DispatchQueue.main.async {
                completion(true, "Git push initiated via AFC tunnel")
            }
        }
    }
}