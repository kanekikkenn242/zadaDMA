import SwiftUI

@main
struct zadaDMAApp: App {
    @StateObject var state = AppState()

    init() {
        PairingController.shared.prepareBackgroundTask()
    }

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(state)
        }
    }
}
