import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !state.hasCompletedOnboarding {
                OnboardingView()
            } else if !state.isActivated {
                ProfileView(showCloseButton: false)
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
    }
}
