import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pairing = PairingController.shared

    @State private var showImporter = false
    @State private var importAlert = false
    @State private var importMessage = ""

    // MARK: - Container detection
    @State private var containerDetectionEnabled = true
    @State private var isScanning = false
    @State private var containersFound: Int? = nil

    // MARK: - Verified versions
    @State private var ios27Expanded = true

    private var deviceIOSVersionText: String {
        let build = DeviceInfo().buildNumber
        return build.isEmpty ? state.deviceiOS : "\(state.deviceiOS) (\(build))"
    }

    private var exploitCompatible: Bool {
        VerifiedVersions.isCompatible(version: state.deviceiOS, build: DeviceInfo().buildNumber)
    }

    private var appearanceBinding: Binding<String> {
        Binding(get: { state.appearance }, set: { state.appearance = $0 })
    }

    private var languageBinding: Binding<String> {
        Binding(get: { state.language }, set: { state.language = $0 })
    }

    var body: some View {
        NavigationView {
            List {
                // App identity
                Section {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.appOrange)
                            .frame(width: 52, height: 52)
                            .overlay(Text("X").font(.system(size: 24, weight: .heavy)).foregroundColor(.white))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("X")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("v\(state.appVersion)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(state.t("signed_apple"))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }

                // Language
                Section(header: Text(state.t("language")).textCase(nil)) {
                    Picker(state.t("language"), selection: languageBinding) {
                        Text("Español").tag("Español")
                        Text("English").tag("English")
                        Text("Português").tag("Português")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)
                }

                // Appearance
                Section(header: Text(state.t("appearance")).textCase(nil)) {
                    Picker(state.t("appearance"), selection: appearanceBinding) {
                        Text(state.t("system")).tag("System")
                        Text(state.t("light")).tag("Light")
                        Text(state.t("dark")).tag("Dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)
                }

                // Device
                Section(header: Text(state.t("device_section")).textCase(nil)) {
                    HStack {
                        Text(state.t("hardware_model"))
                        Spacer()
                        Text(state.deviceModel).foregroundColor(.gray)
                    }
                    HStack {
                        Text(state.t("ios_version"))
                        Spacer()
                        Text(deviceIOSVersionText).foregroundColor(.gray)
                    }
                }

                // Container detection
                Section(header: Text(state.t("container_detection")).textCase(nil)) {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appOrange)
                            .frame(width: 28, height: 28)
                            .background(Color.appOrange.opacity(0.15))
                            .cornerRadius(7)
                        Text(state.t("container_toggle"))
                            .font(.system(size: 15))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Toggle("", isOn: $containerDetectionEnabled)
                            .labelsHidden()
                            .tint(.appOrange)
                    }

                    if isScanning {
                        HStack(spacing: 10) {
                            ProgressView().tint(.appOrange)
                            Text(state.t("scanning")).foregroundColor(.gray)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise").foregroundColor(.appOrange)
                            Text(state.t("scanning")).foregroundColor(.gray)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.appGreen)
                            Text(Localization.shared.format("containers_found", lang: state.language, containersFound ?? 0))
                                .foregroundColor(.white)
                        }
                        Text(state.t("method"))
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: startScan) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise").foregroundColor(.appOrange)
                                Text(state.t("rescan")).foregroundColor(.white)
                            }
                        }
                    }

                    Text(state.t("container_desc"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Pairing & tunnel
                Section(header: Text(state.t("pairing_tunnel")).textCase(nil)) {
                    HStack {
                        Circle()
                            .fill(pairing.hasPairingFile ? Color.appGreen : Color.appRed)
                            .frame(width: 8, height: 8)
                        Text(pairing.hasPairingFile ? state.t("connected") : state.t("not_connected"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    HStack {
                        Text(state.t("pairing_status"))
                        Spacer()
                        Text(pairing.hasPairingFile ? state.t("pairing_ready") : state.t("not_connected"))
                            .foregroundColor(pairing.hasPairingFile ? .appGreen : .gray)
                    }

                    Text(state.t("pairing_desc"))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if !pairing.hasPairingFile && !pairing.isPairing {
                        Button(action: { startPairing() }) {
                            Text(state.t("start_pairing"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appOrange)
                                .cornerRadius(10)
                        }
                    }
                    if pairing.isPairing {
                        Button(action: { pairing.stopPairing() }) {
                            Text(state.t("stop_pairing"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.appRed)
                                .cornerRadius(10)
                        }
                        if !pairing.currentPin.isEmpty {
                            Text("PIN: \(pairing.currentPin)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.appOrange)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    Button(action: openVPN) {
                        HStack {
                            Image(systemName: "network").foregroundColor(.appOrange)
                            Text(state.t("open_vpn")).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.appOrange)
                        }
                        .padding(.vertical, 10)
                    }

                    Button(action: { showImporter = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down").foregroundColor(.appOrange)
                            Text(state.t("import_pair")).foregroundColor(.white)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.appOrange)
                        }
                        .padding(.vertical, 10)
                    }
                }

                // Verified versions
                Section(header: Text(state.t("verified_versions")).textCase(nil)) {
                    HStack {
                        Text(state.t("exploit_compat"))
                        Spacer()
                        Text(exploitCompatible ? state.t("compatible") : state.t("not_compatible"))
                            .foregroundColor(exploitCompatible ? .appGreen : .appRed)
                    }

                    ForEach(VerifiedVersions.legacyGroups, id: \.self) { group in
                        HStack {
                            Text(group)
                            Spacer()
                            Text(Localization.shared.format("exact_builds", lang: state.language, VerifiedVersions.exactBuilds[group] ?? 0))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button(action: { withAnimation { ios27Expanded.toggle() } }) {
                        HStack {
                            Text("iOS 27")
                            Spacer()
                            Text(Localization.shared.format("exact_builds", lang: state.language, VerifiedVersions.exactBuilds["iOS 27"] ?? 0))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Image(systemName: ios27Expanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)

                    if ios27Expanded {
                        ForEach(VerifiedVersions.ios27Groups, id: \.title) { group in
                            HStack(alignment: .top) {
                                Text(group.title).font(.system(size: 15))
                                Spacer()
                                Text(group.builds.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 16)
                        }
                    }

                    Text(state.t("footer_verified"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                // Social networks
                Section(header: Text(state.t("social_networks")).textCase(nil)) {
                    SocialRow(icon: "paperplane.fill", title: "Telegram", subtitle: state.t("announcements"))
                    SocialRow(icon: "bubble.left.and.bubble.right.fill", title: "Discord", subtitle: state.t("community"))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .task(id: containerDetectionEnabled) {
                if containerDetectionEnabled { startScan() }
            }
            .navigationTitle(state.t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(state.t("done")) { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appOrange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let ok = pairing.importPairingFile(url: url)
                    importMessage = ok ? "✅ \(state.t("pairing_ready"))" : "❌ \(pairing.pairingStatus)"
                    importAlert = true
                case .failure(let error):
                    importMessage = "❌ \(error.localizedDescription)"
                    importAlert = true
                }
            }
            .alert(state.t("settings"), isPresented: $importAlert) {
                Button(state.t("ok")) { }
            } message: {
                Text(importMessage)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startScan() {
        isScanning = true
        containersFound = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let count = MotorBridge.appContainers()?.count ?? 0
            DispatchQueue.main.async {
                self.isScanning = false
                self.containersFound = count
            }
        }
    }

    private func startPairing() {
        pairing.startPairing { _ in }
    }

    private func openVPN() {
        guard let url = URL(string: "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=LocalDevVPN") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

private struct SocialRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appOrange)
                .frame(width: 28, height: 28)
                .background(Color.appOrange.opacity(0.15))
                .cornerRadius(7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(.appOrange)
        }
    }
}
