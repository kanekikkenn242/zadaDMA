import SwiftUI

struct SupportView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "headphones").font(.system(size: 60)).foregroundColor(.appOrange).padding(30).background(Color.appCard).cornerRadius(20).padding(.top, 20)
                Text(state.t("support_center")).font(.title.bold()).foregroundColor(.white)
                Text("Discord announcements and help").foregroundColor(.gray).font(.caption)
                
                VStack(spacing: 12) {
                    LinkRow(icon: "bubble.left.and.bubble.right.fill", title: state.t("discord_sup"), subtitle: "Direct help", url: "https://discord.gg/wpqqTnfXfc")
                    LinkRow(icon: "megaphone.fill", title: state.t("discord_ann"), subtitle: "Announcements and downloads", url: "https://discord.gg/wAAbwX8Dmc")
                    LinkRow(icon: "checklist", title: state.t("check_status"), subtitle: "Compare changes", url: "https://github.com/0xjohnnydev/MobileHouseArrest-PoC")
                    
                    // Shtuar linket tjera
                    LinkRow(icon: "link", title: "Geod-MCM-PoC", subtitle: "partDomain traversal", url: "https://github.com/0xjohnnydev/Geod-MCM-PoC")
                    LinkRow(icon: "link", title: "InstallCoordination-PoC", subtitle: "final-symlink chain", url: "https://github.com/0xjohnnydev/InstallCoordination-PoC")
                    LinkRow(icon: "link", title: "CFPrefsZeroFile-PoC", subtitle: "cfprefsd zero-file", url: "https://github.com/0xjohnnydev/CFPrefsZeroFile-PoC")
                }.padding(.horizontal)
            }
        }
    }
}

struct LinkRow: View {
    let icon: String; let title: String; let subtitle: String; let url: String
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack {
                Image(systemName: icon).foregroundColor(.appOrange).padding(12).background(Color.black).cornerRadius(12)
                VStack(alignment: .leading) {
                    Text(title).foregroundColor(.white).font(.headline)
                    Text(subtitle).foregroundColor(.gray).font(.caption)
                }
                Spacer()
                Image(systemName: "arrow.up.right").foregroundColor(.gray)
            }.cardStyle()
        }
    }
}
