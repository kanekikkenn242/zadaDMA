import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                HomeView().tag(0)
                FreeFireView().tag(1)
                ProfileView().tag(2) // E RREGULLUAR: Pa parametra
                SupportView().tag(3)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                TabButton(icon: "house.fill", title: state.t("home"), isSelected: tab == 0) { withAnimation { tab = 0 } }
                Spacer()
                TabButton(icon: "gamecontroller.fill", title: state.t("game"), isSelected: tab == 1) { withAnimation { tab = 1 } }
                Spacer()
                TabButton(icon: "person.fill", title: state.t("profile"), isSelected: tab == 2) { withAnimation { tab = 2 } }
                Spacer()
                TabButton(icon: "questionmark.circle", title: state.t("support"), isSelected: tab == 3) { withAnimation { tab = 3 } }
            }
            .padding(.horizontal, 20).padding(.vertical, 15)
            .background(Color.appCard)
            .clipShape(Capsule())
            .padding(.horizontal, 20).padding(.bottom, 10)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? Color(white: 0.15) : Color.clear)
            .cornerRadius(12)
        }
    }
}
