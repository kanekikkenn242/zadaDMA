import SwiftUI

@main
struct zadaDMAApp: App {
    @StateObject var state = AppState()
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(state)
                .preferredColorScheme(.dark)
        }
    }
}
