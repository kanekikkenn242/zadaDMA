import Foundation

/// Drives one toggle: unpack the .3105, push the file through the pairing tunnel,
/// keep the displaced original, and restore it when the toggle goes off.
@MainActor
struct PatchInstaller {
    let state: AppState

    func toggle(_ feature: PatchFeature) {
        guard state.busyFeature == nil else { return }

        let enable = !state.installedFeatures.contains(feature.id)
        state.busyFeature = feature.id

        Task { await run(feature, enable: enable) }
    }

    private func run(_ feature: PatchFeature, enable: Bool) async {
        defer { state.busyFeature = nil }

        guard state.pairingReady else {
            state.log.error("pairing not configured — import a record and set the tunnel port")
            state.phase = .failed("pairing not configured")
            return
        }

        let settings = state.settings
        let bundle = state.bundleIdentifier
        let backup = Self.backupURL(feature: feature, bundle: bundle)
        let meta = Self.metaURL(feature: feature, bundle: bundle)
        let destination = (try? String(contentsOf: meta, encoding: .utf8)) ?? feature.packageDestination

        state.log.info(enable
            ? "\(feature.title): opening tunnel to \(settings.host):\(settings.port)"
            : "\(feature.title): restoring original from backup")

        do {
            let steps = try await Task.detached(priority: .userInitiated) { () -> [String] in
                var steps: [String] = []

                if enable {
                    let package = try PatchPackageCodec.load(resource: feature.packageResource)
                    steps.append("package \(package.identifier) verified (\(package.data.count) bytes)")
                    let staged = try PatchPackageCodec.stage(package.data, named: package.identifier)
                    let remote = try Airlift.apply(settings,
                                                   bundle: bundle,
                                                   destination: package.destination,
                                                   sourcePath: staged.path,
                                                   sha256: package.sha256,
                                                   backupPath: backup.path)
                    try? package.destination.write(to: meta, atomically: true, encoding: .utf8)
                    steps.append("replaced \(remote)")
                } else {
                    guard FileManager.default.fileExists(atPath: backup.path) else {
                        throw AirliftError.failed("no backup recorded for \(feature.title)")
                    }
                    let remote = try Airlift.restore(settings,
                                                     bundle: bundle,
                                                     destination: destination,
                                                     backupPath: backup.path)
                    steps.append("restored \(remote)")
                }
                return steps
            }.value

            steps.forEach(state.log.info)
            state.markInstalled(feature.id, enable)
            state.phase = .ready("paired")
            state.log.ok(enable ? "\(feature.title) active" : "\(feature.title) removed")
        } catch {
            state.log.error(error.localizedDescription)
            state.phase = .failed(error.localizedDescription)
        }
    }

    static func backupURL(feature: PatchFeature, bundle: String) -> URL {
        directory().appendingPathComponent("\(bundle)-\(feature.id).orig")
    }

    static func metaURL(feature: PatchFeature, bundle: String) -> URL {
        directory().appendingPathComponent("\(bundle)-\(feature.id).dst")
    }

    private static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("zadaDMA/backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
