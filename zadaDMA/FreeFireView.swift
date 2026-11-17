import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    @State private var subTab = 0

    private var gameName: String {
        state.selectedGame.isEmpty ? state.t("ffmax") : state.selectedGame
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Game header
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.appOrange, Color.red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(gameName)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            Text(state.t("ready_to_load"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.appOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.appOrange.opacity(0.15))
                                .cornerRadius(6)
                        }
                        Text(Localization.shared.format("live_count", lang: state.language, 2))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: refreshCatalog) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 36, height: 36)
                            .background(Color.appCard)
                            .clipShape(Circle())
                    }
                }
                .padding(.top, 12)

                HStack {
                    Spacer()
                    Text(state.t("time_left"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }

                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(icon: "scope", title: state.t("aimbot"), active: state.selectedCategory == "Aimbot") { state.selectedCategory = "Aimbot" }
                        categoryChip(icon: "cube", title: state.t("holograma"), active: state.selectedCategory == "Holograma") { state.selectedCategory = "Holograma" }
                        categoryChip(icon: "paintbrush.fill", title: state.t("skin"), active: state.selectedCategory == "Skin") { state.selectedCategory = "Skin" }
                        categoryChip(icon: "ellipsis.circle", title: state.t("others"), active: state.selectedCategory == "Otros") { state.selectedCategory = "Otros" }
                    }
                }

                // Catalog status
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.appOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.t("catalog_loaded"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text(Localization.shared.format("products_ready", lang: state.language, 15, 0, 0))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.appCard)
                .cornerRadius(14)

                // Sub tabs
                HStack(spacing: 10) {
                    subTabButton(title: state.t("aimbot_cache"), index: 0)
                    subTabButton(title: state.t("aimbot_avatar"), index: 1)
                }

                // Feature cards
                Group {
                    if state.selectedCategory == "Aimbot" || state.selectedCategory == "Otros" {
                        PatchCard(
                            title: state.t("aim_drag"),
                            isEnabled: state.aimbotDragEnabled,
                            loadLabel: state.t("load"),
                            loadedLabel: state.t("loaded"),
                            notLoadedLabel: state.t("not_loaded"),
                            safeLabel: state.t("safe")
                        ) {
                            state.toggleFeature("AIM DRAG", isOn: !state.aimbotDragEnabled, patchFile: "aimneck_cache")
                        }
                        PatchCard(
                            title: state.t("aim_chest"),
                            isEnabled: state.aimPeitoEnabled,
                            loadLabel: state.t("load"),
                            loadedLabel: state.t("loaded"),
                            notLoadedLabel: state.t("not_loaded"),
                            safeLabel: state.t("safe")
                        ) {
                            state.toggleFeature("AIM PECHO", isOn: !state.aimPeitoEnabled, patchFile: "aimtorso_cache")
                        }
                    }
                    if state.selectedCategory == "Holograma" || state.selectedCategory == "Otros" {
                        PatchCard(
                            title: "HOLOGRAMA PURPLE",
                            isEnabled: state.hologramEnabled,
                            loadLabel: state.t("load"),
                            loadedLabel: state.t("loaded"),
                            notLoadedLabel: state.t("not_loaded"),
                            safeLabel: state.t("safe")
                        ) {
                            state.toggleFeature("HOLOGRAMA", isOn: !state.hologramEnabled, patchFile: "hologram")
                        }
                    }
                    if state.selectedCategory == "Skin" || state.selectedCategory == "Otros" {
                        PatchCard(
                            title: "SKIN VIP",
                            isEnabled: state.skinEnabled,
                            loadLabel: state.t("load"),
                            loadedLabel: state.t("loaded"),
                            notLoadedLabel: state.t("not_loaded"),
                            safeLabel: state.t("safe")
                        ) {
                            state.toggleFeature("SKIN", isOn: !state.skinEnabled, patchFile: "skin")
                        }
                    }
                }

                // Logs
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.t("logs"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    ForEach(state.patchLog.suffix(4), id: \.self) { log in
                        Text(log)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if state.patchLog.isEmpty {
                        Text("—")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private func refreshCatalog() {
        state.patchLog.append("🔄 \(state.t("catalog_loaded"))")
    }

    private func categoryChip(icon: String, title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(active ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(active ? Color.appOrange : Color.appCard)
            .cornerRadius(20)
        }
    }

    private func subTabButton(title: String, index: Int) -> some View {
        Button(action: { withAnimation { subTab = index } }) {
            HStack(spacing: 6) {
                Image(systemName: index == 0 ? "externaldrive.fill" : "person.crop.circle.fill")
                    .font(.system(size: 12))
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(subTab == index ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(subTab == index ? Color.appOrange : Color.appCard)
            .cornerRadius(10)
        }
    }
}

private struct PatchCard: View {
    let title: String
    let isEnabled: Bool
    let loadLabel: String
    let loadedLabel: String
    let notLoadedLabel: String
    let safeLabel: String
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scope")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .frame(width: 46, height: 46)
                    .background(Color.black.opacity(0.45))
                    .cornerRadius(12)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(action: onLoad) {
                    Text(isEnabled ? loadedLabel : loadLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appOrange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().stroke(Color.appOrange, lineWidth: 1)
                        )
                }
            }

            HStack(spacing: 8) {
                Text(isEnabled ? loadedLabel : notLoadedLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isEnabled ? .appGreen : .gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isEnabled ? Color.appGreen : Color.gray).opacity(0.15))
                    .cornerRadius(6)
                Text(safeLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.appGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appGreen.opacity(0.12))
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.appCard)
        .cornerRadius(16)
    }
}
