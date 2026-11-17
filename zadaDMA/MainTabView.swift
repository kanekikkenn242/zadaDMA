import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                HomeView().tag(0)
                FreeFireView().tag(1)
                ProfileView().tag(2)
                SupportView().tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 4) {
                TabButton(icon: "house.fill", title: state.t("home"), isSelected: tab == 0) { withAnimation { tab = 0 } }
                Spacer().frame(maxWidth: 28)
                TabButton(icon: "gamecontroller.fill", title: state.t("game"), isSelected: tab == 1, prominent: true) { withAnimation { tab = 1 } }
                Spacer().frame(maxWidth: 28)
                TabButton(icon: "person.fill", title: state.t("profile"), isSelected: tab == 2) { withAnimation { tab = 2 } }
                Spacer()
                TabButton(icon: "questionmark.circle", title: state.t("support"), isSelected: tab == 3) { withAnimation { tab = 3 } }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appCard)
            .clipShape(Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: prominent ? 22 : 18))
                    .foregroundColor(prominent ? Color.appOrange : (isSelected ? .white : .gray))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .frame(minWidth: prominent ? 74 : 54)
            .padding(.horizontal, 10)
            .padding(.vertical, prominent ? 10 : 8)
            .background(isSelected ? Color.appOrange.opacity(0.18) : Color.clear)
            .cornerRadius(14)
        }
    }
}
