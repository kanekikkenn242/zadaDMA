import SwiftUI
struct WallpaperLab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo").font(.system(size: 44)).foregroundStyle(.purple)
            Text("WallpaperLab").font(.title.bold())
            Text("crop → .tendies → PosterBoard").foregroundStyle(.secondary)
        }
    }
}
