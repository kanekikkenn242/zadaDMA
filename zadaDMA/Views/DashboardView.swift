import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var tab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $tab) {
                FuncoesTab().tag(0)
                PartidasTab().tag(1)
                ConfigTab().tag(2)
            }.tabViewStyle(.page(indexDisplayMode: .never))
            
            // Tab Bar
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

struct FuncoesTab: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "tree.fill").resizable().scaledToFill().frame(height: 140).clipped().cornerRadius(16).overlay(Color.black.opacity(0.4)).padding(.horizontal)
                
                Text("FUNÇÕES").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                
                VStack(spacing: 8) {
                    ToggleRow(title: "Hs Cabeça", subtitle: "Neck + Side + Up", isOn: Binding(get: { state.hsCabeca }, set: { v in state.hsCabeca = v; state.startInjection(name: "Hs Cabeça", patchFile: "aimdrag_neck") }))
                    ToggleRow(title: "AIM NECK 90%", subtitle: "Neck + Chest 90%", isOn: Binding(get: { state.hsAlto }, set: { v in state.hsAlto = v; state.startInjection(name: "Aim Neck 90%", patchFile: "aimneck_90") }))
                    ToggleRow(title: "Hs Peito", subtitle: "Hs Body cache", isOn: Binding(get: { state.hsPeito }, set: { v in state.hsPeito = v; state.startInjection(name: "Hs Peito", patchFile: "aimpeito") }))
                    ToggleRow(title: "Antenna Mão", subtitle: "Antenna on Hand", isOn: Binding(get: { state.antennaMao }, set: { v in state.antennaMao = v; state.startInjection(name: "Antenna", patchFile: "antenna") }))
                }.padding(.horizontal)
            }.padding(.top, 20).padding(.bottom, 100)
        }
    }
}

struct PartidasTab: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("PARTIDAS").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                VStack(spacing: 8) {
                    ToggleRow(title: "Painel", subtitle: "Painel Silent", isOn: $state.hsPeito)
                    ToggleRow(title: "Aimbot e Esp", subtitle: "Aimbot e ESP", isOn: $state.aimbotEsp)
                    ToggleRow(title: "120/144 FPS", subtitle: "Desbloqueio de FPS", isOn: $state.skin)
                }.padding(.horizontal)
            }.padding(.top, 40).padding(.bottom, 100)
        }
    }
}

struct ConfigTab: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 44, height: 44).foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("bnxyung7").font(.system(size: 12)).foregroundStyle(.gray)
                        Text(state.timeRemaining).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "moon.fill").font(.system(size: 16)).padding(10).background(Color(white: 0.15)).clipShape(Circle())
                }.padding(.horizontal, 16).padding(.top, 16)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Status da conta").font(.system(size: 12)).foregroundStyle(.gray)
                        Text("Ativo").font(.system(size: 16, weight: .bold)).foregroundStyle(.green)
                    }
                    Spacer()
                }.padding(14).background(Color(white: 0.1)).cornerRadius(14).padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("DISPOSITIVO").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    VStack(spacing: 1) {
                        InfoRow(icon: "iphone", title: "Modelo", value: state.deviceModel)
                        InfoRow(icon: "gear", title: "iOS", value: state.deviceiOS)
                    }.cornerRadius(14)
                }.padding(.horizontal, 16)
            }.padding(.bottom, 100)
        }
    }
}

struct ToggleRow: View {
    let title: String, subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.85)
        }.padding(.horizontal, 16).padding(.vertical, 12).background(Color(white: 0.1)).cornerRadius(14)
    }
}

struct InfoRow: View {
    let icon: String, title: String, value: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.gray).frame(width: 18)
            Text(title).font(.system(size: 14)).foregroundStyle(.gray)
            Spacer()
            Text(value).font(.system(size: 14)).foregroundStyle(.white)
        }.padding(14).background(Color(white: 0.1))
    }
}

struct TabBtn: View {
    let icon: String, title: String, isSel: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 10, weight: .medium))
            }.foregroundStyle(isSel ? .white : .gray).frame(width: 60)
        }
    }
}
