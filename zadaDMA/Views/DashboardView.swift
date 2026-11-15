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
            
            if state.activeInjectionName != nil { InjectionOverlay() }
        }
    }
}

struct FuncoesTab: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("FUNÇÕES").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                
                VStack(spacing: 8) {
                    ToggleRow(title: "Hs Cabeça", subtitle: "Neck + Side + Up", isOn: Binding(get: { state.hsCabecaEnabled }, set: { v in state.hsCabecaEnabled = v; state.startInjection(featureName: "Hs Cabeça", isOn: v, patchName: "aimdrag_neck") }))
                    ToggleRow(title: "AIM NECK 90%", subtitle: "Neck + Chest 90%", isOn: Binding(get: { state.hsCabeca90Enabled }, set: { v in state.hsCabeca90Enabled = v; state.startInjection(featureName: "Aim Neck 90%", isOn: v, patchName: "aimneck_90") }))
                }.padding(.horizontal)
            }.padding(.top, 20)
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
                    ToggleRow(title: "Painel", subtitle: "Painel Silent", isOn: $state.painelEnabled)
                    ToggleRow(title: "Aimbot e Esp", subtitle: "Aimbot e ESP", isOn: $state.aimbotEspEnabled)
                }.padding(.horizontal)
            }.padding(.top, 40)
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
                        Text("zadaDMA").font(.system(size: 12)).foregroundStyle(.gray)
                        Text(state.timeRemaining).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    }
                    Spacer()
                }.padding(.horizontal, 16).padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("DISPOSITIVO").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    VStack(spacing: 1) {
                        InfoRow(icon: "iphone", title: "Modelo", value: state.deviceModel)
                        InfoRow(icon: "gear", title: "iOS", value: state.deviceiOS)
                    }.cornerRadius(14)
                }.padding(.horizontal, 16)
            }
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
