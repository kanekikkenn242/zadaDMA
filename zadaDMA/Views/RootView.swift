import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @AppStorage("onboarding.done") private var onboarded = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if onboarded {
                TabView {
                    DashboardView()
                        .tabItem { Label("Patches", systemImage: "square.grid.2x2") }

                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .accentColor(Theme.accent)
            } else {
                OnboardingView { onboarded = true }
            }
        }
    }
}
