import SwiftUI
@MainActor
final class AppState: ObservableObject {
    enum Phase { case booting, antiTamper, forceUpdate, welcome, dashboard, blocked(String) }
    @Published var phase: Phase = .booting
    @Published var products: [Product] = []
    @Published var containers: [String] = []
    @Published var sandboxReady = false
    @Published var log: [String] = []

    func boot() {
        var e: NSError?
        if !MotorBridge.bootstrap(withError: &e) {
            phase = .antiTamper
            log.append("anti-tamper: \(e?.localizedDescription ?? "?")")
            return
        }
        AppUpdateChecker.check { [weak self] blocked, reason in
            Task { @MainActor in
                guard let self else { return }
                if blocked { self.phase = .blocked(reason ?? "blocked"); return }
                self.phase = .welcome
            }
        }
    }
    func enterDashboard() { phase = .dashboard; preload() }
    func preload() {
        MotorBridge.ensureSandbox { [weak self] ok, _ in
            Task { @MainActor in
                guard let self else { return }
                self.sandboxReady = ok
                if ok { self.containers = (MotorBridge.appContainers() as? [String]) ?? [] }
                self.log.append("sandbox=\(ok) containers=\(self.containers.count)")
            }
        }
    }
    func apply(packageData: Data, bundleID: String, pass: String) {
        var e: NSError?
        let ok = MotorBridge.applyPackageData(packageData, passphrase: pass, bundleID: bundleID, error: &e)
        log.append("patch \(bundleID): \(ok ? "ok" : e?.localizedDescription ?? "fail")")
    }
}
struct Product: Identifiable { let id, name, slug, category: String }
