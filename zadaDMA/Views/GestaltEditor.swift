import SwiftUI
struct GestaltEditor: View {
    @State private var ipad = false, ai = false, region = false
    var body: some View {
        Form {
            Toggle("iPadOS Mode", isOn: $ipad)
            Toggle("Apple Intelligence", isOn: $ai)
            Toggle("Region Lock", isOn: $region)
            Section { Text("Gestalt writes require sandbox access").font(.caption) }
        }.navigationTitle("Gestalt")
    }
}
