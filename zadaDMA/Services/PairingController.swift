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
    
    private var connectFn: ConnectFn?
    private var writeFn: WriteFn?
    private var closeFn: CloseFn?
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
        let connectNames = ["idevice_afc_connect_with_pairing_file", "idevice_connect_with_pairing_file", "idevice_connect"]
        let writeNames = ["idevice_afc_write_file", "idevice_afc_write", "idevice_write_file"]
        let closeNames = ["idevice_afc_close", "idevice_close"]
        let containerNames = ["idevice_house_arrest_get_container_path", "idevice_get_app_container", "idevice_afc_get_container_path"]
        
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
    }
    
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
    
    func getContainerPath(bundleID: String) -> String? {
        guard hasPairingFile, let getContainer = getContainerFn else { return nil }
        var outPath: UnsafeMutablePointer<CChar>? = nil
        let result = pairingFilePath.withCString { pp in
            bundleID.withCString { bp in
                getContainer(pp, bp, &outPath)
            }
        }
        if result == 0, let pathPtr = outPath {
            let path = String(cString: pathPtr)
            free(pathPtr)
            return path
        }
        return nil
    }
    
    func injectFile(localPath: String, remotePath: String) -> Bool {
        guard hasPairingFile, let connect = connectFn, let write = writeFn else { return false }
        let client = pairingFilePath.withCString { pp in
            "127.0.0.1".withCString { hp in
                connect(pp, hp, 49152)
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
}
