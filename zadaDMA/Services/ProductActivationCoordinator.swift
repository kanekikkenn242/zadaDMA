import Foundation
@MainActor
final class ProductActivationCoordinator: ObservableObject {
    @Published var busy = false
    @Published var message: String?
    func activate(slug: String, bundleID: String, pass: String, in state: AppState) async {
        busy = true; defer { busy = false }
        do {
            let (pkgData, prod) = try await RemotePatchStore.shared.fetchFile(slug: slug)
            state.apply(packageData: pkgData, bundleID: bundleID, pass: pass)
            message = "applied \(prod.name)"
        } catch {
            message = "fail: \(error.localizedDescription)"
        }
    }
}
