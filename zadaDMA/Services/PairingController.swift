import Foundation
import UIKit

// Funksionet e librarise Rust "idevice" (FFI)
// Nese emrat ndryshojne, shiko vendor/idevice/ffi/examples/
@_silgen_name("idevice_afc_connect_with_pairing_file")
func idevice_afc_connect_with_pairing_file(_ pairingPath: UnsafePointer<CChar>, _ host: UnsafePointer<CChar>, _ port: UInt16) -> Int32

@_silgen_name("idevice_afc_write_file")
func idevice_afc_write_file(_ client: Int32, _ remotePath: UnsafePointer<CChar>, _ localPath: UnsafePointer<CChar>) -> Int32

@_silgen_name("idevice_afc_close")
func idevice_afc_close(_ client: Int32) -> Int32

class PairingController: ObservableObject {
    static let shared = PairingController()
    
    @Published var hasPairingFile: Bool = false
    
    private var pairingFilePath: String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pairing.plist").path
    }
    
    init() {
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
            print("[Airlift] Pairing file u ruajt: \(pairingFilePath)")
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
        
        print("[Airlift] Duke u lidhur me 127.0.0.1:49152...")
        let client = pairingFilePath.withCString { pp in
            "127.0.0.1".withCString { hp in
                idevice_afc_connect_with_pairing_file(pp, hp, 49152)
            }
        }
        
        if client < 0 {
            print("[-] Lidhja deshtoi. A eshte LocalDevVPN aktiv?")
            return false
        }
        
        print("[Airlift] Duke derguar: \(localPath) -> \(remotePath)")
        let result = localPath.withCString { lp in
            remotePath.withCString { rp in
                idevice_afc_write_file(client, rp, lp)
            }
        }
        
        _ = idevice_afc_close(client)
        
        if result == 0 {
            print("[Airlift] Sukses!")
            return true
        } else {
            print("[-] Dergimi deshtoi")
            return false
        }
    }
}
