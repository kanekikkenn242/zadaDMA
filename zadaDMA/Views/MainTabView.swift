import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 1
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $tab) {
                HomeView().tag(0)
                FreeFireView().tag(1)
                ProfileView(showCloseButton: true).tag(2)
                SupportView().tag(3)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom Tab Bar me madhësi fikse
            HStack {
                TabButton(icon: "house.fill", title: "Inicio", isSelected: tab == 0) { tab = 0 }
                Spacer()
                TabButton(icon: "gamecontroller.fill", title: "Free Fire", isSelected: tab == 1) { tab = 1 }
                Spacer()
                TabButton(icon: "person.fill", title: "Perfil", isSelected: tab == 2) { tab = 2 }
                Spacer()
                TabButton(icon: "questionmark.circle", title: "Soporte", isSelected: tab == 3) { tab = 3 }
            }
            .padding(.horizontal, 24)
            .frame(height: 60) // Lartësi fikse
            .background(Color(white: 0.1))
            .clipShape(Capsule())
            .padding(.horizontal, 20).padding(.bottom, 20)
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
                Text(title).font(.system(size: 10, weight: .medium)) // Font fiks
            }
            .foregroundColor(isSelected ? .white : .gray)
            .frame(width: 60, height: 44) // Kufizim i gjerësisë dhe lartësisë
            .background(isSelected ? Color(white: 0.2) : Color.clear)
            .cornerRadius(12)
        }
    }
}
