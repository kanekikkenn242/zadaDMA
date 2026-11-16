import Foundation
import UIKit
import Darwin

class PairingController: ObservableObject {
    static let shared = PairingController()
    
    @Published var hasPairingFile: Bool = false
    
    private typealias ConnectFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UInt16) -> Int32
    private typealias WriteFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias CloseFn = @convention(c) (Int32) -> Int32
    private typealias GetContainerFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32
    private typealias StartPairingFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    
    private var connectFn: ConnectFn?
    private var writeFn: WriteFn?
    private var closeFn: CloseFn?
    private var getContainerFn: GetContainerFn?
    private var startPairingFn: StartPairingFn?
    
    private var pairingFilePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pairing.plist").path
    }
    
    init() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
        loadSymbols()
    }
    
    private func loadSymbols() {
        let connectNames = ["idevice_afc_connect_with_pairing_file", "idevice_connect_with_pairing_file", "idevice_connect"]
        let writeNames = ["idevice_afc_write_file", "idevice_afc_write", "idevice_write_file"]
        let closeNames = ["idevice_afc_close", "idevice_close"]
        let containerNames = ["idevice_house_arrest_get_container_path", "idevice_get_app_container", "idevice_afc_get_container_path"]
        let pairingNames = ["idevice_rppairing_start_host", "idevice_start_pairing_host"]
        
        for name in connectNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                connectFn = unsafeBitCast(ptr, to: ConnectFn.self); break
            }
        }
        for name in writeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                writeFn = unsafeBitCast(ptr, to: WriteFn.self); break
            }
        }
        for name in closeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                closeFn = unsafeBitCast(ptr, to: CloseFn.self); break
            }
        }
        for name in containerNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                getContainerFn = unsafeBitCast(ptr, to: GetContainerFn.self); break
            }
        }
        for name in pairingNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                startPairingFn = unsafeBitCast(ptr, to: StartPairingFn.self); break
            }
        }
    }
    
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
                completion(result == 0)
            }
        }
    }
    
    func stopPairing() {
        // Nese ka nje funksion per te ndaluar, e therrasim
        print("[Pairing] Stopped.")
    }
    
    // ... (funksionet e tjera si getContainerPath, injectFile, importPairingFile mbeten te njejtat) ...
}
