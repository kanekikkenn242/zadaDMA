import SwiftUI

struct SupportView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "headphones").font(.system(size: 60)).foregroundColor(.appOrange).padding(30).background(Color.appCard).cornerRadius(20)
                Text("Support Center").font(.title.bold()).foregroundColor(.white)
                Text("Discord announcements and help").foregroundColor(.gray)
                
                VStack(spacing: 12) {
                    SupportRow(icon: "bubble.left.and.bubble.right.fill", title: "Discord support", subtitle: "Direct help")
                    SupportRow(icon: "megaphone.fill", title: "Discord announcements", subtitle: "Announcements and downloads")
                    SupportRow(icon: "checklist", title: "Check status", subtitle: "Compare changes")
                }.padding(.horizontal)
            }
        }
    }
}

struct SupportRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(.appOrange).padding(12).background(Color.black).cornerRadius(12)
            VStack(alignment: .leading) {
                Text(title).foregroundColor(.white).font(.headline)
                Text(subtitle).foregroundColor(.gray).font(.caption)
            }
            Spacer()
            Image(systemName: "arrow.up.right").foregroundColor(.gray)
        }.padding().cardStyle()
    }
}
