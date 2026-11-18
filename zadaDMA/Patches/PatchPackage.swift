import Foundation
import CryptoKit

struct PatchPackage {
    let identifier: String
    let name: String
    let bundleIdentifier: String?
    let destination: String
    let sha256: String
    let data: Data
}

enum PatchPackageError: LocalizedError {
    case truncated
    case badMagic
    case unsupportedSchema(UInt16)
    case passwordRequired
    case malformedManifest
    case digestMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .truncated:
            return "package is truncated"
        case .badMagic:
            return "not a .3105 package"
        case .unsupportedSchema(let version):
            return "unsupported package schema \(version)"
        case .passwordRequired:
            return "package is password protected"
        case .malformedManifest:
            return "package manifest is unreadable"
        case .digestMismatch(let expected, let actual):
            return "payload digest \(actual) does not match \(expected)"
        }
    }
}

/// Layout (little endian):
///   "3105" u16 schema u16 aadVersion u16 flags u32 iterations
///   u32 idLen + id, u32 saltLen + salt, u32 manifestLen + manifest,
///   u32 payloadLen + payload, 32-byte sha256 of the plaintext payload.
enum PatchPackageCodec {
    static let flagPasswordProtected: UInt16 = 1 << 0

    static func load(resource name: String) throws -> PatchPackage {
        guard let url = Bundle.main.url(forResource: name, withExtension: "3105") else {
            throw AirliftError.failed("\(name).3105 is missing from the app bundle")
        }
        return try load(url: url)
    }

    static func load(url: URL, password: String? = nil) throws -> PatchPackage {
        var reader = ByteReader(try Data(contentsOf: url))

        guard let magic = reader.take(4), magic == Data("3105".utf8) else {
            throw PatchPackageError.badMagic
        }
        guard let schema = reader.u16(), let aadVersion = reader.u16(),
              let flags = reader.u16(), let iterations = reader.u32() else {
            throw PatchPackageError.truncated
        }
        _ = aadVersion
        guard schema == 2 else { throw PatchPackageError.unsupportedSchema(schema) }

        guard let identifier = reader.utf8(), let salt = reader.data(),
              let manifestData = reader.data(), let payload = reader.data(),
              let expectedDigest = reader.take(32) else {
            throw PatchPackageError.truncated
        }

        let plain: Data
        if flags & flagPasswordProtected != 0 {
            guard let password, !password.isEmpty else { throw PatchPackageError.passwordRequired }
            let key = try pbkdf2Key(password: password, salt: salt, iterations: iterations)
            plain = try decrypt(payload, key: key)
        } else {
            plain = payload
        }

        let digest = sha256Hex(plain)
        let expected = hexString(expectedDigest)
        guard digest == expected else {
            throw PatchPackageError.digestMismatch(expected: expected, actual: digest)
        }

        guard let manifest = try? JSONDecoder().decode(Manifest.self, from: manifestData),
              let file = manifest.files.first else {
            throw PatchPackageError.malformedManifest
        }

        return PatchPackage(identifier: manifest.id,
                            name: manifest.name,
                            bundleIdentifier: manifest.bundle,
                            destination: file.dst,
                            sha256: file.sha256 ?? digest,
                            data: plain)
    }

    /// Writes the package payload to a temp file so the C layer can read it.
    static func stage(_ data: Data, named name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("zadaDMA-staging", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).payload")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Manifest

    private struct Manifest: Decodable {
        struct File: Decodable {
            let dst: String
            let sha256: String?
        }

        let id: String
        let name: String
        let bundle: String?
        let files: [File]
    }

    // MARK: - Crypto

    private static func pbkdf2Key(password: String, salt: Data, iterations: UInt32) throws -> SymmetricKey {
        let passwordChars = Array(password.utf8CString)
        var derived = [UInt8](repeating: 0, count: kCCKeySizeAES256)

        let status = passwordChars.withUnsafeBufferPointer { pw in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                                     pw.baseAddress,
                                     max(pw.count - 1, 0),
                                     saltBytes.bindMemory(to: UInt8.self).baseAddress,
                                     salt.count,
                                     CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                                     iterations,
                                     &derived,
                                     derived.count)
            }
        }

        guard status == kCCSuccess else {
            throw AirliftError.failed("PBKDF2 failed (\(status))")
        }
        return SymmetricKey(data: Data(derived))
    }

    private static func decrypt(_ blob: Data, key: SymmetricKey) throws -> Data {
        guard blob.count > 28 else { throw PatchPackageError.truncated }
        do {
            let box = try AES.GCM.SealedBox(combined: blob)
            return try AES.GCM.open(box, using: key)
        } catch {
            throw AirliftError.failed("package decryption failed")
        }
    }

    static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

private struct ByteReader {
    private let data: Data
    private var offset = 0

    init(_ data: Data) {
        self.data = data
    }

    var remaining: Int { data.count - offset }

    mutating func take(_ count: Int) -> Data? {
        guard count >= 0, remaining >= count else { return nil }
        let start = data.startIndex + offset
        offset += count
        return data[start..<start + count]
    }

    mutating func u16() -> UInt16? {
        guard let bytes = take(2) else { return nil }
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }

    mutating func u32() -> UInt32? {
        guard let bytes = take(4) else { return nil }
        let b = bytes.startIndex
        return UInt32(bytes[b])
            | (UInt32(bytes[b + 1]) << 8)
            | (UInt32(bytes[b + 2]) << 16)
            | (UInt32(bytes[b + 3]) << 24)
    }

    mutating func data() -> Data? {
        guard let length = u32() else { return nil }
        return take(Int(length))
    }

    mutating func utf8() -> String? {
        guard let bytes = data() else { return nil }
        return String(data: bytes, encoding: .utf8)
    }
}
