import Foundation

enum AirliftError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

/// Thin, blocking wrapper over airlift.h. Every call opens and closes a tunnel,
/// so always invoke it from a background task.
enum Airlift {
    static func probe(_ settings: PairingSettings, bundle: String) throws -> String {
        var out = [CChar](repeating: 0, count: 1024)
        var err = [CChar](repeating: 0, count: 1024)

        let code = al_probe(settings.pairingPath, settings.host, settings.port, settings.pin,
                            &out, out.count, &err, err.count)

        guard code == 0 else {
            throw AirliftError.failed(describe(err, fallback: "probe failed (code \(code))"))
        }
        return describe(out, fallback: "")
    }

    static func apply(_ settings: PairingSettings,
                      bundle: String,
                      destination: String,
                      sourcePath: String,
                      sha256: String?,
                      backupPath: String) throws -> String {
        var out = [CChar](repeating: 0, count: 1024)
        var err = [CChar](repeating: 0, count: 1024)

        let code = al_apply_file(settings.pairingPath, settings.host, settings.port, settings.pin,
                                 bundle, destination, sourcePath, sha256 ?? "", backupPath,
                                 &out, out.count, &err, err.count)

        guard code == 0 else {
            throw AirliftError.failed(describe(err, fallback: "write failed (code \(code))"))
        }
        return describe(out, fallback: destination)
    }

    static func restore(_ settings: PairingSettings,
                        bundle: String,
                        destination: String,
                        backupPath: String) throws -> String {
        var out = [CChar](repeating: 0, count: 1024)
        var err = [CChar](repeating: 0, count: 1024)

        let code = al_restore_file(settings.pairingPath, settings.host, settings.port, settings.pin,
                                   bundle, destination, backupPath,
                                   &out, out.count, &err, err.count)

        guard code == 0 else {
            throw AirliftError.failed(describe(err, fallback: "restore failed (code \(code))"))
        }
        return describe(out, fallback: destination)
    }

    private static func describe(_ buffer: [CChar], fallback: String) -> String {
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let text = String(decoding: bytes, as: UTF8.self)
        return text.isEmpty ? fallback : text
    }
}
