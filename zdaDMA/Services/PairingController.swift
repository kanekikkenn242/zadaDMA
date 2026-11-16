import Foundation
import UIKit
import Combine
import Darwin

class PairingController: ObservableObject {
    static let shared = PairingController()

    @Published var hasPairingFile: Bool = false
    @Published var pairingStatus: String = "Idle"
    @Published var currentPin: String = ""

    // MARK: - C ABI typealiases
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

    // MARK: - Symbol loading
    private func loadSymbols() {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)

        for name in ["idevice_afc_connect_with_pairing_file",
                     "idevice_connect_with_pairing_file",
                     "idevice_connect"] {
            if let ptr = dlsym(rtldDefault, name) {
                connectFn = unsafeBitCast(ptr, to: ConnectFn.self)
                print("[Pairing] Connect: \(name)")
                break
            }
        }
        for name in ["idevice_afc_write", "idevice_write_file"] {
            if let ptr = dlsym(rtldDefault, name) {
                writeFn = unsafeBitCast(ptr, to: WriteFn.self)
                print("[Pairing] Write: \(name)")
                break
            }
        }
        for name in ["idevice_afc_close", "idevice_close"] {
            if let ptr = dlsym(rtldDefault, name) {
                closeFn = unsafeBitCast(ptr, to: CloseFn.self)
                print("[Pairing] Close: \(name)")
                break
            }
        }
        for name in ["idevice_start_pairing_host",
                     "idevice_rppairing_start_host",
                     "idevice_pairing_start"] {
            if let ptr = dlsym(rtldDefault, name) {
                startPairingFn = unsafeBitCast(ptr, to: StartPairingFn.self)
                print("[Pairing] StartPairing: \(name)")
                break
            }
        }
        for name in ["zdma_generate_pin", "idevice_generate_pin"] {
            if let ptr = dlsym(rtldDefault, name) {
                generatePinFn = unsafeBitCast(ptr, to: GeneratePinFn.self)
                print("[Pairing] GeneratePin: \(name)")
                break
            }
        }
        for name in ["idevice_house_arrest_get_container_path",
                     "idevice_get_app_container",
                     "idevice_afc_get_container_path"] {
            if let ptr = dlsym(rtldDefault, name) {
                getContainerFn = unsafeBitCast(ptr, to: GetContainerFn.self)
                print("[Pairing] Container: \(name)")
                break
            }
        }
    }

    // MARK: - PIN
    func generatePin() -> String {
        var pinBuf = [CChar](repeating: 0, count: 7)
        let result = generatePinFn?(&pinBuf, UInt32(pinBuf.count))
        if result == 0 {
            let pin = String(cString: pinBuf)
            currentPin = pin
            return pin
        }
        print("[-] Failed to generate PIN, result: \(String(describing: result))")
        return "000000"
    }

    // MARK: - Pairing
    func startPairing(pin: String, completion: @escaping (Bool) -> Void) {
        guard let startPairing = startPairingFn else {
            print("[-] Funksioni i pairing nuk u gjet.")
            completion(false)
            return
        }
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

    // MARK: - Inject (used by AppState)
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

        // FIX #5: keep the C-string pointers inside their withCString scopes.
        let success: Bool = localPath.withCString { lp -> Bool in
            remotePath.withCString { rp -> Bool in
                writeC(client, rp, lp) == 0
            }
        }

        if let closeC = closeFn { _ = closeC(client) }
        return success
    }

    // MARK: - Container path
    func getContainerPath(bundleID: String) -> String? {
        guard hasPairingFile, let getContainer = getContainerFn else {
            print("[-] getContainerPath: pairing ose funksion mungon")
            return nil
        }
        var outPath: UnsafeMutablePointer<CChar>? = nil
        if let pp = pairingFilePath.cString(using: .utf8),
           let bp = bundleID.cString(using: .utf8) {
            let result = getContainer(pp, bp, &outPath)
            if result == 0, let pathPtr = outPath {
                let path = String(cString: pathPtr)
                free(pathPtr)
                return path
            }
        }
        return nil
    }

    // MARK: - Helpers
    func reloadPairingFile() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
    }

    func importPairingFile(url: URL) -> Bool {
        do {
            let dest = URL(fileURLWithPath: pairingFilePath)
            if FileManager.default.fileExists(atPath: pairingFilePath) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
            hasPairingFile = true
            return true
        } catch {
            print("[-] Gabim: \(error)")
            return false
        }
    }

    // MARK: - Write .3105 via AFC
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

        let fullRemotePath = "\(remoteDir)/\(filename)"
        var success = false
        if let rp = fullRemotePath.cString(using: .utf8) {
            // FIX #2 + #5: unwrap + keep pointer inside withUnsafeBytes.
            let writeResult: Int32 = localData.withUnsafeBytes { rawBuf -> Int32 in
                guard let base = rawBuf.baseAddress else { return -1 }
                let ptr = base.assumingMemoryBound(to: CChar.self)
                return writeC(client, rp, ptr)
            }
            success = writeResult == 0
        }

        if let closeC = closeFn { _ = closeC(client) }
        return success
    }

    // MARK: - AFC "git push" stub
    // NOTE: `Process` exists only on macOS — it is not available on iOS.
    // A real git push must be done via a helper binary/service, not in-app.
    func gitPush(to remoteURL: String, branch: String = "main",
                 completion: @escaping (Bool, String) -> Void) {
        guard hasPairingFile else {
            completion(false, "Pairing file missing")
            return
        }
        guard let connectC = connectFn, let writeC = writeFn else {
            completion(false, "Required symbols missing")
            return
        }

        let pairingPath = self.pairingFilePath
        let closeC      = self.closeFn

        DispatchQueue.global(qos: .background).async {
            var client: Int32 = -1
            if let pp = pairingPath.cString(using: .utf8),
               let hp = "127.0.0.1".cString(using: .utf8) {
                // FIX #3: use the local `connectC`, not the Darwin `connect`.
                client = connectC(pp, hp, 49152)
            }

            guard client >= 0 else {
                DispatchQueue.main.async { completion(false, "Failed to connect") }
                return
            }

            // FIX #6: close once, after the loop, on every exit path.
            defer {
                if let closeC = closeC { _ = closeC(client) }
            }

            let tunnelFiles = ["project.yml", "Info.plist", "Assets.car"]

            for remoteFile in tunnelFiles {
                let base = remoteFile.replacingOccurrences(of: ".plist", with: "")
                let type = remoteFile.hasSuffix(".plist") ? "plist" : nil

                guard let bundlePath = Bundle.main.path(forResource: base, ofType: type),
                      let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath)),
                      let rp = remoteFile.cString(using: .utf8) else { continue }

                // FIX #4 + #5: use `writeC` explicitly, keep pointer in scope.
                _ = data.withUnsafeBytes { rawBuf -> Int32 in
                    guard let base = rawBuf.baseAddress else { return -1 }
                    let ptr = base.assumingMemoryBound(to: CChar.self)
                    return writeC(client, rp, ptr)
                }
            }

            DispatchQueue.main.async {
                completion(true, "Git push initiated via AFC tunnel — git binary execution pending")
            }
        }
    }
}
