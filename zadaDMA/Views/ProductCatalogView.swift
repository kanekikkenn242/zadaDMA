import SwiftUI
struct ProductCatalogView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var coord = ProductActivationCoordinator()
    let products: [(String,String,String)] = [
        ("Aim Head",             "aim-head",      "AIMBOT"),
        ("Aim Neck",             "aim-neck",      "AIMBOT"),
        ("Chams + Purple Holo",  "chams-purple",  "CHAMS"),
        ("Unlock FPS 144",       "fps-144",       "FPS"),
        ("Mod Skin",             "mod-skin",      "SKIN"),
    ]
    var body: some View {
        NavigationStack {
            List(products, id: \.0) { p in
                HStack {
                    VStack(alignment: .leading) { Text(p.0).font(.headline)
                                                  Text(p.2).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                    Button("Apply") {
                        Task { await coord.activate(slug: p.1, bundleID: "com.dts.freefireth",
                                                    pass: "shared-server-secret", in: state) }
                    }.buttonStyle(.bordered)
                }
            }.navigationTitle("Products")
        }
    }
}
