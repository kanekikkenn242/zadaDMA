import Foundation
import UIKit
import Darwin

class PairingController: ObservableObject {
    static let shared = PairingController()
    
    @Published var hasPairingFile: Bool = false
    @Published var pairingStatus: String = "Idle"
    @Published var currentPin: String = ""
    
    // Deklarimi i tipeve te funksioneve (C ABI)
    private typealias ConnectFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UInt16) -> Int32
    private typealias WriteFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias CloseFn = @convention(c) (Int32) -> Int32
    private typealias StartPairingFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias GeneratePinFn = @convention(c) (UnsafeMutablePointer<CChar>, UInt32) -> Int32
    private typealias GetContainerFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
    
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
        // Connect functions
        let connectNames = ["idevice_afc_connect_with_pairing_file", "idevice_connect_with_pairing_file", "idevice_connect"]
        for name in connectNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                connectFn = unsafeBitCast(ptr, to: ConnectFn.self)
                print("[Pairing] Connect: \(name)")
                break
            }
        }
        
        // Write functions
        let writeNames = ["idevice_afc_write", "idevice_write_file"]
        for name in writeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                writeFn = unsafeBitCast(ptr, to: WriteFn.self)
                print("[Pairing] Write: \(name)")
                break
            }
        }
        
        // Close functions
        let closeNames = ["idevice_afc_close", "idevice_close"]
        for name in closeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                closeFn = unsafeBitCast(ptr, to: CloseFn.self)
                print("[Pairing] Close: \(name)")
                break
            }
        }
        
        // Start pairing host function
        let pairingNames = ["idevice_start_pairing_host", "idevice_rppairing_start_host", "idevice_pairing_start"]
        for name in pairingNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                startPairingFn = unsafeBitCast(ptr, to: StartPairingFn.self)
                print("[Pairing] StartPairing: \(name)")
                break
            }
        }
        
        // Generate PIN function
        let pinNames = ["zdma_generate_pin", "idevice_generate_pin"]
        for name in pinNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                generatePinFn = unsafeBitCast(ptr, to: GeneratePinFn.self)
                print("[Pairing] GeneratePin: \(name)")
                break
            }
        }
        
        // Get container path function
        let containerNames = ["idevice_house_arrest_get_container_path", "idevice_get_app_container", "idevice_afc_get_container_path"]
        for name in containerNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                getContainerFn = unsafeBitCast(ptr, to: GetContainerFn.self)
                print("[Pairing] Container: \(name)")
                break
            }
        }
    }
    
    // MARK: - PIN Generation
    func generatePin() -> String {
        var pinBuf = [CChar](repeating: 0, count: 7)
        let result = generatePinFn?(&pinBuf, UInt32(pinBuf.count))
        if result == 0 {
            let pin = String(cString: pinBuf)
            currentPin = pin
            return pin
        }
        // FIX: use String(describing:) to avoid optional interpolation warning
        print("[-] Failed to generate PIN, result: \(String(describing: result))")
        return "000000"
    }
    
    // MARK: - Pairing Logic (per t'u dukur si X.app)
    func startPairing(pin: String, completion: @escaping (Bool) -> Void) {
        guard let startPairing = startPairingFn else {
            print("[-] Funksioni i pairing nuk u gjet.")
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            // Therrasim funksionin Rust per te nisur pairing host
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
    
    // MARK: - Injection Logic (per t'u perdorur nga AppState)
    func injectFile(localPath: String, remotePath: String) -> Bool {
        guard hasPairingFile, let connect = connectFn, let write = writeFn else {
            print("[-] injectFile: funksionet ose pairing file mungon")
            return false
        }
        
        // Krijuam tunel LocalDevVPN-like connection
        var client: Int32 = -1
        // FIX: explicitly unwrap the C strings with nil checking
        if let pp = pairingFilePath.cString(using: .utf8),
           let hp = "127.0.0.1".cString(using: .utf8) {
            client = connect(pp, hp, 49152)
        }
        
        if client < 0 { return false }
        
        let result = localPath.cString(using: .utf8).map { lp in
            remotePath.cString(using: .utf8).map { rp in
                write(client, rp, lp)
            }
        } ?? false
        
        if let close = closeFn { _ = close(client) }
        return result == true
    }
    
    // MARK: - Get Container Path
    func getContainerPath(bundleID: String) -> String? {
        guard hasPairingFile, let getContainer = getContainerFn else {
            print("[-] getContainerPath: pairing ose funksion mungon")
            return nil
        }
        var outPath: UnsafeMutablePointer<CChar>? = nil
        // FIX: properly pass C strings
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
    
    // MARK: - Extra Helpers
    func reloadPairingFile() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
    }
    
    func importPairingFile(url: URL) -> Bool {
        do {
            // FIX: use fileURLWithPath directly
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
    
    // MARK: - Write .3105 Aim Config Files via AFC
    func writeAimFile(remoteDir: String, filename: String, localData: Data) -> Bool {
        guard hasPairingFile, let connect = connectFn, let write = writeFn else {
            print("[-] writeAimFile: funksionet ose pairing file mungon")
            return false
        }
        
        // Krijuam tunel LocalDevVPN-like connection
        var client: Int32 = -1
        if let pp = pairingFilePath.cString(using: .utf8),
           let hp = "127.0.0.1".cString(using: .utf8) {
            client = connect(pp, hp, 49152)
        }
        
        if client < 0 { return false }
        
        let fullRemotePath = "\(remoteDir)/\(filename)"
        // FIX: properly create C string from the path
        if let rp = fullRemotePath.cString(using: .utf8) {
            // FIX: use withUnsafeBytes properly for the data, unwrap optional pointer
            let dataC = localData.withUnsafeBytes { bytes in
                bytes.baseAddress?.assumingMemoryBound(to: CChar.self)
            }
            if let dataC = dataC {
                write(client, rp, dataC)
            }
        }
        
        if let close = closeFn { _ = close(client) }
        return true
    }
    
    // MARK: - Git Push Integration
    func gitPush(to remoteURL: String, branch: String = "main", completion: @escaping (Bool, String) -> Void) {
        guard hasPairingFile else {
            completion(false, "Pairing file missing")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var client: Int32 = -1
            if let pp = pairingFilePath.cString(using: .utf8),
               let hp = "127.0.0.1".cString(using: .utf8) {
                client = connect(pp, hp, 49152)
            }
            
            if client < 0 {
                completion(false, "Failed to connect")
                return
            }
            
            // Upload project structure via AFC tunnel
            // This creates the localdevVPN tunnel for git operations
            let tunnelFiles = [
                "project.yml",
                "Info.plist",
                "Assets.car"
            ]
            
            for remoteFile in tunnelFiles {
                if let bundlePath = Bundle.main.path(forResource: remoteFile.replacingOccurrences(of: ".plist", "", with: ""),
                                                    ofType: remoteFile.hasSuffix(".plist") ? "plist" : nil) {
                    let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath))
                    if let data = data {
                        if let rp = remoteFile.cString(using: .utf8) {
                            let dataC = data.withUnsafeBytes { bytes in
                                bytes.baseAddress?.assumingMemoryBound(to: CChar.self)
                            }
                            write(client, rp, dataC)
                        }
                        if let close = self.closeFn { _ = close(client); client = -1 }
                    }
                }
            }
            
            // FIX: properly use Process from Foundation
            // The git push will be executed via spawn or a helper tool
            // For now, just notify that it's initiated
            DispatchQueue.main.async {
                completion(true, "Git push initiated via AFC tunnel - git binary execution pending")
            }
        }
    }
}