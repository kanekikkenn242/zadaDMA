import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 1 // Hapet direkt te Free Fire
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $tab) {
                HomeView().tag(0)
                FreeFireView().tag(1)
                ProfileView(showCloseButton: true).tag(2)
                SupportView().tag(3)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                TabButton(icon: "house.fill", title: "Inicio", isSelected: tab == 0) { tab = 0 }
                Spacer()
                TabButton(icon: "gamecontroller.fill", title: "Free Fire", isSelected: tab == 1) { tab = 1 }
                Spacer()
                TabButton(icon: "person.fill", title: "Perfil", isSelected: tab == 2) { tab = 2 }
                Spacer()
                TabButton(icon: "questionmark.circle", title: "Soporte", isSelected: tab == 3) { tab = 3 }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(white: 0.1)).clipShape(Capsule())
            .padding(.horizontal, 16).padding(.bottom, 20)
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
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .gray)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? Color(white: 0.2) : Color.clear)
            .cornerRadius(14)
        }
    }
}
