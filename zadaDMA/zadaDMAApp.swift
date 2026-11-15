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
        case .blocked(let reason):
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Image(systemName: "xmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.red)
                    Text("Blocked")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text(reason)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
    }
}
