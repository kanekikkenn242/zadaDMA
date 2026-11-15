import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0
    @State private var showActivation = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $tab) {
                HomeView().tag(0)
                if state.isActivated {
                    FreeFireView().tag(1)
                } else {
                    ProfileView(showActivation: $showActivation).tag(1) // Nese s'eshte aktivizuar, tregon profilin
                }
                ProfileView(showActivation: $showActivation).tag(2)
                SupportView().tag(3)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                TabButton(icon: "house.fill", title: state.t("home"), isSelected: tab == 0) { tab = 0 }
                Spacer()
                TabButton(icon: "gamecontroller.fill", title: state.t("game"), isSelected: tab == 1) { tab = 1 }
                Spacer()
                TabButton(icon: "person.fill", title: state.t("profile"), isSelected: tab == 2) { tab = 2 }
                Spacer()
                TabButton(icon: "questionmark.circle", title: state.t("support"), isSelected: tab == 3) { tab = 3 }
            }
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Color.appCard).clipShape(Capsule())
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .sheet(isPresented: $showActivation) {
            ProfileView(showActivation: $showActivation)
        }
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
