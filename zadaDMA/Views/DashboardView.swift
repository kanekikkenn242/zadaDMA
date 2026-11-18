import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var state: AppState
    @State private var showLogs = false

    private var installer: PatchInstaller { PatchInstaller(state: state) }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard

                    SectionLabel(text: "Free Fire patches")

                    ForEach(PatchFeature.all) { feature in
                        featureCard(feature)
                    }

                    logCard
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("zadaDMA")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showLogs) {
                LogView(log: state.log)
            }
        }
        .navigationViewStyle(.stack)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tunnel")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                StatusPill(text: phaseText, tint: phaseTint)
            }

            Text(state.pairingReady ? "\(state.host):\(state.portText)" : "no pairing record configured")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.muted)

            Text(state.bundleIdentifier)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Theme.muted)
        }
        .card()
    }

    private func featureCard(_ feature: PatchFeature) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(feature.subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if state.busyFeature == feature.id {
                ProgressView().tint(Theme.accent)
            } else {
                Toggle("", isOn: Binding(
                    get: { state.installedFeatures.contains(feature.id) },
                    set: { _ in installer.toggle(feature) }
                ))
                .labelsHidden()
                .tint(Theme.accent)
            }
        }
        .card()
    }

    private var logCard: some View {
        Button {
            showLogs = true
        } label: {
            HStack {
                Text("Injection log")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Text("\(state.log.entries.count)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var phaseText: String {
        switch state.phase {
        case .idle: return "idle"
        case .connecting: return "connecting"
        case .ready: return "ready"
        case .failed: return "error"
        }
    }

    private var phaseTint: Color {
        switch state.phase {
        case .idle: return Theme.muted
        case .connecting: return Color.orange
        case .ready: return Theme.accent
        case .failed: return Theme.danger
        }
    }
}
