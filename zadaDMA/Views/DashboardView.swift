import SwiftUI
struct DashboardView: View {
    var body: some View {
        TabView {
            ProductCatalogView().tabItem { Label("Products",   systemImage: "shippingbox") }
            FileBrowserView()   .tabItem { Label("Files",      systemImage: "folder") }
            CleanerView()       .tabItem { Label("Cleaner",    systemImage: "sparkles") }
            WallpaperLab()      .tabItem { Label("Wallpapers", systemImage: "photo") }
            GestaltEditor()     .tabItem { Label("Gestalt",    systemImage: "slider.horizontal.3") }
            SettingsView()      .tabItem { Label("Settings",   systemImage: "gearshape") }
        }
    }
}
