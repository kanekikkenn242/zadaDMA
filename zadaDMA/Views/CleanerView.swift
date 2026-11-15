import SwiftUI
struct CleanerView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.purple)
            Text("Cleaner").font(.title.bold())
            Text("Library/Caches + tmp only").foregroundStyle(.secondary)
        }
    }
}
