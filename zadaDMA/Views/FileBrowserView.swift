import SwiftUI
struct FileBrowserView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        NavigationStack {
            List(state.containers, id: \.self) { c in
                Text(c).font(.system(.footnote, design: .monospaced))
            }.navigationTitle("Containers")
        }
    }
}
