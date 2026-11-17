import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var pairing = PairingController.shared
    @State private var showSettings = false

    private var deviceIOSVersionText: String {
        let build = DeviceInfo().buildNumber
        return build.isEmpty ? state.deviceiOS : "\(state.deviceiOS) (\(build))"
    }

    private var iosMinorPrefix: String {
        let parts = state.deviceiOS.split(separator: ".")
        guard parts.count >= 2 else { return state.deviceiOS }
        return "\(parts[0]).\(parts[1])"
    }

    private var exploitCompatible: Bool {
        VerifiedVersions.isCompatible(version: state.deviceiOS, build: DeviceInfo().buildNumber)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Header
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.appOrange)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Text("X")
                                    .font(.system(size: 26, weight: .heavy))
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text("X")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.white)
                            Text(state.deviceModel)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.appOrange)
                        }
                    }
                    .padding(.top, 12)

                    // Support badge
                    HStack {
                        Spacer()
                        Text(Localization.shared.format("supports_ios_badge", lang: state.language, iosMinorPrefix))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.appGreen)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.appGreen.opacity(0.15))
                            .cornerRadius(8)
                    }

                    // Device status
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "cpu")
                                .foregroundColor(.appOrange)
                            Text(state.t("device_status"))
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                        }

                        settingRow(label: state.t("hardware_model"), value: state.deviceModel)
                        Divider().background(Color.white.opacity(0.08))
                        settingRow(label: state.t("ios_version"), value: deviceIOSVersionText)
                        Divider().background(Color.white.opacity(0.08))
                        HStack {
                            Text(state.t("exploit_compat"))
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            Spacer()
                            Text(exploitCompatible ? state.t("supported") : state.t("not_supported"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(exploitCompatible ? .appGreen : .appRed)
                        }
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .cornerRadius(16)

                    // Pairing / injection shortcut
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: pairing.hasPairingFile ? "checkmark.shield.fill" : "exclamationmark.shield")
                                .foregroundColor(pairing.hasPairingFile ? .appGreen : .appOrange)
                            Text(state.t("pairing_tunnel"))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Text(pairing.hasPairingFile ? state.t("connected") : state.t("not_connected"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(pairing.hasPairingFile ? .appGreen : .gray)
                        }
                        Text(pairing.pairingStatus)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(state.t("settings")) { showSettings = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appOrange)
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .cornerRadius(16)

                    Text("v\(state.appVersion)")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
    }

    private func settingRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
    }
}
