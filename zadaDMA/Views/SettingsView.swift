import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    NavigationLink {
                        PairingView()
                    } label: {
                        row(title: "Pairing",
                            detail: state.pairingReady ? "record loaded" : "not configured",
                            symbol: "link")
                    }
                    .buttonStyle(.plain)

                    targetGameCard

                    NavigationLink {
                        LogView(log: state.log)
                    } label: {
                        row(title: "Injection log", detail: "\(state.log.entries.count) entries", symbol: "doc.text")
                    }
                    .buttonStyle(.plain)

                    aboutCard
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }

    private var targetGameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Target")
            Picker("Game", selection: Binding(
                get: { state.bundleIdentifier },
                set: { state.bundleIdentifier = $0; state.persist() }
            )) {
                Text("Free Fire").tag(AppState.freeFireBundle)
                Text("Free Fire MAX").tag(AppState.freeFireMaxBundle)
            }
            .pickerStyle(.segmented)
        }
        .card()
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "About")
            Text("zadaDMA patches files inside another app's container over a paired tunnel. Nothing is injected into memory; the game reads the replaced asset itself.")
                .font(.system(size: 12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private func row(title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.muted)
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
