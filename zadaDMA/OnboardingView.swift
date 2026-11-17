import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 1

    private var lastStep: Int { 5 }

    var body: some View {
        VStack(spacing: 0) {
            // Step indicator
            HStack(spacing: 6) {
                ForEach(1...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.appOrange : Color.gray.opacity(0.3))
                        .frame(width: 26, height: 4)
                }
            }
            .padding(.top, 24)

            ScrollView {
                VStack(spacing: 24) {
                    switch step {
                    case 1: welcomeStep
                    case 2: languageStep
                    case 3: initialSetupStep
                    case 4: supportedStep
                    default: certificateStep
                    }
                }
                .padding(.horizontal)
                .padding(.top, 32)
            }

            // Footer buttons
            HStack(spacing: 12) {
                if step > 1 {
                    Button(state.t("back")) { withAnimation { step -= 1 } }
                        .buttonStyle(DarkButtonStyle())
                }
                Button(step == lastStep ? state.t("finish") : state.t("next")) {
                    withAnimation {
                        if step == lastStep {
                            state.hasCompletedOnboarding = true
                        } else {
                            step += 1
                        }
                    }
                }
                .buttonStyle(OrangeButtonStyle())
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
            .padding(.top, 12)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 20) {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.appOrange)
                .frame(width: 110, height: 110)
                .overlay(
                    Text("X")
                        .font(.system(size: 54, weight: .heavy))
                        .foregroundColor(.white)
                )
                .shadow(color: .appOrange.opacity(0.5), radius: 18)

            Text(state.t("welcome_title"))
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text(state.t("dev_by"))
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 2: Language
    private var languageStep: some View {
        VStack(spacing: 20) {
            Text(state.t("choose_lang"))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(state.t("choose_lang_sub"))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                OnboardingLangRow(title: "Español", subtitle: "Español", selected: state.language == "Español") {
                    withAnimation { state.language = "Español" }
                }
                OnboardingLangRow(title: "English", subtitle: "English", selected: state.language == "English") {
                    withAnimation { state.language = "English" }
                }
                OnboardingLangRow(title: "Português", subtitle: "Português", selected: state.language == "Português") {
                    withAnimation { state.language = "Português" }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Step 3: Initial setup
    private var initialSetupStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.t("initial_setup"))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)
            Text(state.t("initial_sub"))
                .font(.caption)
                .foregroundColor(.gray)

            Text(state.t("appearance"))
                .font(.subheadline.bold())
                .foregroundColor(.white)

            Picker(state.t("appearance"), selection: appearanceBinding) {
                Text(state.t("system")).tag("System")
                Text(state.t("light")).tag("Light")
                Text(state.t("dark")).tag("Dark")
            }
            .pickerStyle(.segmented)

            Text(state.t("game"))
                .font(.subheadline.bold())
                .foregroundColor(.white)

            HStack(spacing: 12) {
                GameSelectionCard(title: state.t("ff"), icon: "flame.fill", isSelected: state.selectedGame == "Free Fire") {
                    withAnimation { state.selectedGame = "Free Fire" }
                }
                GameSelectionCard(title: state.t("ffmax"), icon: "crown.fill", isSelected: state.selectedGame == "Free Fire MAX") {
                    withAnimation { state.selectedGame = "Free Fire MAX" }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 4: Supported iOS versions
    private var supportedStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(state.t("supported_ios"))
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                ForEach(["iOS 17", "iOS 18", "iOS 26"], id: \.self) { group in
                    HStack {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(group)
                            .foregroundColor(.white)
                            .font(.headline)
                        Spacer()
                        Text(Localization.shared.format("exact_builds", lang: state.language, VerifiedVersions.exactBuilds[group] ?? 0))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                }
            }

            Text(Localization.shared.format("this_device", lang: state.language, state.deviceiOS, DeviceInfo().buildNumber))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Step 5: Certificate requirements
    private var certificateStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.appOrange)

            Text(state.t("cert_title"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(state.t("cert_desc"))
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                bullet(icon: "checkmark.circle.fill", color: .appGreen, text: state.t("cert_ok"))
                bullet(icon: "xmark.circle.fill", color: .appRed, text: state.t("cert_no"))
                bullet(icon: "info.circle.fill", color: .gray, text: state.t("cert_note"))
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity)
    }

    private func bullet(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(color)
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appearanceBinding: Binding<String> {
        Binding(get: { state.appearance }, set: { state.appearance = $0 })
    }
}

private struct GameSelectionCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 34))
                    .foregroundColor(isSelected ? .black : .white)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isSelected ? Color.appOrange : Color.appCard)
            .cornerRadius(12)
        }
    }
}

private struct OnboardingLangRow: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.white).font(.headline)
                    Text(subtitle).foregroundColor(.gray).font(.caption)
                }
                Spacer()
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(selected ? .appOrange : .gray)
            }
            .padding()
            .background(Color.appCard)
            .cornerRadius(12)
        }
    }
}
