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
    
    private var connectFn: ConnectFn?
    private var writeFn: WriteFn?
    private var closeFn: CloseFn?
    private var startPairingFn: StartPairingFn?
    private var generatePinFn: GeneratePinFn?
    
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
        print("[-] Failed to generate PIN, result: \(result)")
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
        pairingFilePath.withCString { pp in
            "127.0.0.1".withCString { hp in
                client = connect(pp, hp, 49152)
            }
        }
        
        if client < 0 { return false }
        
        let result = localPath.withCString { lp in
            remotePath.withCString { rp in
                write(client, rp, lp)
            }
        }
        if let close = closeFn { _ = close(client) }
        return result == 0
    }
    
    // MARK: - Extra Helpers
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
    
    // MARK: - Write .3105 Aim Config Files via AFC
    func writeAimFile(remoteDir: String, filename: String, localData: Data) -> Bool {
        guard hasPairingFile, let connect = connectFn, let write = writeFn else {
            print("[-] writeAimFile: funksionet ose pairing file mungon")
            return false
        }
        
        // Krijuam tunel LocalDevVPN-like connection
        var client: Int32 = -1
        pairingFilePath.withCString { pp in
            "127.0.0.1".withCString { hp in
                client = connect(pp, hp, 49152)
            }
        }
        
        if client < 0 { return false }
        
        let fullRemotePath = "\(remoteDir)/\(filename)"
        let remoteC = fullRemotePath.withCString { rp in
            let dataC = localData.withUnsafeBytes { bytes in
                UnsafePointer<CChar>(bytes.baseAddress?.assumingMemoryBound(to: CChar.self) ?? nil) }
            write(client, rp, dataC)
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
            self.pairingFilePath.withCString { pp in
                "127.0.0.1".withCString { hp in
                    client = connect(pp, hp, 49152)
                }
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
                // Read actual file content from bundle
                if let bundlePath = Bundle.main.path(forResource: remoteFile.replacingOccurrences(of: ".plist", "", with: ""),
                                                    ofType: remoteFile.hasSuffix(".plist") ? "plist" : nil) {
                    let data = try? Data(contentsOf: URL(fileURLWithPath: bundlePath))
                    if let data = data {
                        let localC = remoteFile.withCString { rp in
                            write(client, rp, [UInt8](data))
                        }
                        if localC != 0 {
                            if let close = self.closeFn { _ = close(client); client = -1 }
                        }
                    }
                }
            }
            
            // Now execute actual git push
            // This requires git to be available on the device or port forwarding
            let gitTask = Process()
            gitTask.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            gitTask.arguments = ["push", remoteURL, "\(branch)"]
            
            let pipe = Pipe()
            gitTask.standardOutput = pipe
            gitTask.standardError = pipe
            
            do {
                try gitTask.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                DispatchQueue.main.async {
                    if let output = output, !output.contains("fatal") {
                        completion(true, output.isEmpty ? "Git push completed via AFC tunnel" : output)
                    } else {
                        completion(false, "Git push failed: \(output ?? "unknown error")")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, "Git error: \(error.localizedDescription)")
                }
            }
        }
    }
}