import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $tab) {
                FuncoesView().tag(0)
                PartidasView().tag(1)
                ConfigTab().tag(2)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            HStack {
                TabBtn(icon: "square.grid.2x2.fill", title: "Funções", isSel: tab == 0) { tab = 0 }
                Spacer()
                TabBtn(icon: "gamecontroller.fill", title: "Partidas", isSel: tab == 1) { tab = 1 }
                Spacer()
                TabBtn(icon: "person.fill", title: "Config", isSel: tab == 2) { tab = 2 }
            }
            .padding(.horizontal, 30).padding(.vertical, 12)
            .background(Color(white: 0.1)).clipShape(Capsule())
            .padding(.horizontal, 40).padding(.bottom, 20)
            
            if state.injectionName != nil { InjectionOverlay() }
        }
    }
}

struct FuncoesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("FUNÇÕES").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                
                VStack(spacing: 8) {
                    ToggleRow(title: "Hs Cabeça", subtitle: "Neck + Side + Up", isOn: Binding(get: { state.hsCabeca }, set: { v in state.hsCabeca = v; state.startInjection(name: "Hs Cabeça", patchFile: "aimdrag_neck") }))
                    ToggleRow(title: "AIM NECK 90%", subtitle: "Neck + Chest 90%", isOn: Binding(get: { state.hsCabeca90 }, set: { v in state.hsCabeca90 = v; state.startInjection(name: "Aim Neck 90%", patchFile: "aimneck_90") }))
                }.padding(.horizontal)
            }.padding(.top, 20)
        }
    }
}

// (Pjesa tjetër e UI-së: PartidasView, ConfigTab, ToggleRow, TabBtn, InjectionOverlay mbeten të njëjtat)
