import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showSplash {
                SplashView(showSplash: $showSplash)
            } else if !state.hasCompletedOnboarding {
                OnboardingView()
            } else if !state.isActivated {
                MainTabView() // Hapet direkt, por tab-i i Profile kërkon çelës
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(state.colorScheme)
    }
}
