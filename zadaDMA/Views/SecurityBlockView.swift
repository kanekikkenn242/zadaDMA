import SwiftUI
struct SecurityBlockView: View {
    let reason: String
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.shield").font(.system(size: 56)).foregroundStyle(.red)
            Text("Blocked").font(.title.bold())
            Text(reason).foregroundStyle(.secondary)
        }.padding()
    }
}
struct BlockedAccessView: View {
    let reason: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.octagon").font(.system(size: 48)).foregroundStyle(.orange)
            Text(reason).multilineTextAlignment(.center).padding()
        }
    }
}
