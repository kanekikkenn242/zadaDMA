import SwiftUI
@main
struct zadaDMAApp: App {
    @StateObject var state = AppState()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(state).task { state.boot() } }
    }
}
struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        switch state.phase {
        case .booting:        ProgressView("Initialising")
        case .antiTamper:     SecurityBlockView(reason: "identity")
        case .forceUpdate:    BlockedAccessView(reason: "app version blocked")
        case .welcome:        OnboardingView()
        case .blocked(let r): SecurityBlockView(reason: r)
        case .dashboard:      DashboardView()
        }
    }
}
