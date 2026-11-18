import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @State private var showActivation = false
    @State private var keyInput = ""
    @State private var errorMsg = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Membership card
                VStack(spacing: 12) {
                    Image(systemName: state.isActivated ? "checkmark.seal.fill" : "lock.shield.fill")
                        .font(.system(size: 46))
                        .foregroundColor(state.isActivated ? .appGreen : .appOrange)
                    Text(state.isActivated ? state.t("premium_active") : state.t("no_membership"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Text(state.t("membership_hint"))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .background(Color.appCard)
                .cornerRadius(16)

                // Activate key
                Button { showActivation = true } label: {
                    HStack(spacing: 12) {
                        profileIcon("key.fill")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.t("activate_key"))
                                .foregroundColor(.white)
                                .font(.headline)
                            Text(state.t("enter_key"))
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }
                    .cardStyle()
                }

                // Game selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        profileIcon("gamecontroller.fill")
                        Text(state.t("game"))
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    HStack(spacing: 10) {
                        gameChip(title: state.t("ff"), icon: "flame.fill", selected: state.selectedGame == "Free Fire") {
                            withAnimation { state.selectedGame = "Free Fire" }
                        }
                        gameChip(title: state.t("ffmax"), icon: "crown.fill", selected: state.selectedGame == "Free Fire MAX") {
                            withAnimation { state.selectedGame = "Free Fire MAX" }
                        }
                    }
                }
                .cardStyle()

                // Notices
                HStack(spacing: 12) {
                    profileIcon("bell.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.t("notices")).foregroundColor(.white).font(.headline)
                        Text(state.t("notices_sub")).foregroundColor(.gray).font(.caption)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.gray)
                }
                .cardStyle()

                // Music
                HStack(spacing: 12) {
                    profileIcon("music.note")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.t("music")).foregroundColor(.white).font(.headline)
                        Text(state.t("music_sub")).foregroundColor(.gray).font(.caption)
                    }
                    Spacer()
                    Toggle("", isOn: $state.musicEnabled)
                        .labelsHidden()
                        .tint(.appOrange)
                }
                .cardStyle()
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $showActivation) {
            VStack(spacing: 20) {
                Text(state.t("activate_key"))
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text(state.t("membership_hint"))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                TextField(state.t("your_key"), text: $keyInput)
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !errorMsg.isEmpty {
                    Text(errorMsg).foregroundColor(.red).font(.caption)
                }

                Button(state.t("activate")) {
                    if keyInput == "ZADADMA2026" {
                        state.isActivated = true
                        errorMsg = ""
                        showActivation = false
                    } else {
                        errorMsg = state.t("invalid_key")
                    }
                }
                .buttonStyle(OrangeButtonStyle())

                Button(state.t("close")) { showActivation = false }
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .presentationDetents([.height(320)])
        }
    }

    private func profileIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.appOrange)
            .frame(width: 34, height: 34)
            .background(Color.black)
            .cornerRadius(10)
    }

    private func gameChip(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(selected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? Color.appOrange : Color.black.opacity(0.5))
            .cornerRadius(10)
        }
    }
}
