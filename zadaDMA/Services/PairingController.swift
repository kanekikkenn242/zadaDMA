import Foundation
import UIKit
import Darwin

class PairingController: ObservableObject {
    static let shared = PairingController()
    
    @Published var hasPairingFile: Bool = false
    
    // Pointerat e funksioneve (te gjetur ne runtime me dlsym)
    private typealias ConnectFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UInt16) -> Int32
    private typealias WriteFn = @convention(c) (Int32, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32
    private typealias CloseFn = @convention(c) (Int32) -> Int32
    
    private var connectFn: ConnectFn?
    private var writeFn: WriteFn?
    private var closeFn: CloseFn?
    
    private var pairingFilePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pairing.plist").path
    }
    
    init() {
        hasPairingFile = FileManager.default.fileExists(atPath: pairingFilePath)
        loadSymbols()
    }
    
    private func loadSymbols() {
        // Provojme disa emra te mundshem per funksionet e FFI
        let connectNames = [
            "idevice_afc_connect_with_pairing_file",
            "idevice_connect_with_pairing_file",
            "idevice_connect",
            "afc_connect",
            "idevice_afc_connect"
        ]
        let writeNames = [
            "idevice_afc_write_file",
            "idevice_afc_write",
            "afc_write_file",
            "idevice_write_file"
        ]
        let closeNames = [
            "idevice_afc_close",
            "idevice_close",
            "afc_close"
        ]
        
        for name in connectNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                connectFn = unsafeBitCast(ptr, to: ConnectFn.self)
                print("[Airlift] Gjeta funksionin e lidhjes: \(name)")
                break
            }
        }
        for name in writeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                writeFn = unsafeBitCast(ptr, to: WriteFn.self)
                print("[Airlift] Gjeta funksionin e shkrimit: \(name)")
                break
            }
        }
        for name in closeNames {
            if let ptr = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) {
                closeFn = unsafeBitCast(ptr, to: CloseFn.self)
                print("[Airlift] Gjeta funksionin e mbylljes: \(name)")
                break
            }
        }
        
        if connectFn == nil || writeFn == nil {
            print("[Airlift] [-] Nuk u gjeten funksionet FFI te idevice.")
            print("[Airlift] Kontrollo emrat real me: nm libidevice_ffi.a | grep idevice")
        }
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
    
    func injectFile(localPath: String, remotePath: String) -> Bool {
        guard hasPairingFile else {
            print("[-] Pairing file mungon")
            return false
        }
        guard let connect = connectFn, let write = writeFn else {
            print("[-] Funksionet Airlift nuk u gjeten. Kontrollo librarine idevice.")
            return false
        }
        
        let client = pairingFilePath.withCString { pp in
            "127.0.0.1".withCString { hp in
                connect(pp, hp, 49152)
            }
        }
        
        if client < 0 {
            print("[-] Lidhja deshtoi. A eshte LocalDevVPN aktiv?")
            return false
        }
        
        let result = localPath.withCString { lp in
            remotePath.withCString { rp in
                write(client, rp, lp)
            }
        }
        
        if let close = closeFn { _ = close(client) }
        return result == 0
    }
}
