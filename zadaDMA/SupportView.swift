import SwiftUI

struct SupportView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Image(systemName: "headphones")
                        .font(.system(size: 54))
                        .foregroundColor(.appOrange)
                        .padding(26)
                        .background(Color.appCard)
                        .cornerRadius(20)
                    Text(state.t("support_center"))
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text(state.t("community"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.top, 24)

                VStack(spacing: 12) {
                    LinkRow(icon: "bubble.left.and.bubble.right.fill",
                            title: state.t("discord_support"),
                            subtitle: state.t("direct_help"),
                            url: "https://discord.gg/wpqqTnfXfc")
                    LinkRow(icon: "megaphone.fill",
                            title: state.t("discord_announcements"),
                            subtitle: state.t("announcements_downloads"),
                            url: "https://discord.gg/wAAbwX8Dmc")
                    LinkRow(icon: "gift.fill",
                            title: state.t("giveaway"),
                            subtitle: state.t("giveaway_sub"),
                            url: "https://discord.gg/wAAbwX8Dmc")
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

private struct LinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.appOrange)
                    .frame(width: 34, height: 34)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundColor(.white).font(.headline)
                    Text(subtitle).foregroundColor(.gray).font(.caption)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundColor(.appOrange).font(.caption)
            }
            .cardStyle()
        }
    }
}
