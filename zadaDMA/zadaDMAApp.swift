import SwiftUI

@main
struct zadaDMAApp: App {
    @StateObject var state = AppState()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(state).task { state.boot() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        switch state.phase {
        case .booting:
            ZStack {
                Color.black.ignoresSafeArea()
                ProgressView().tint(.white)
            }
        case .license:
            LicenseGate()
        case .dashboard:
            DashboardView()
        }
    }
}
