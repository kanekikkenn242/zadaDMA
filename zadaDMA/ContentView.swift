import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showSplash = true
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showSplash {
                SplashView(showSplash: $showSplash)
                    .transition(.opacity)
            } else if !state.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.move(edge: .trailing))
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut(duration: 0.4), value: state.hasCompletedOnboarding)
        .preferredColorScheme(state.colorScheme)
    }
}
