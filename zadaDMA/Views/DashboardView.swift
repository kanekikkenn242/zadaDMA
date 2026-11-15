import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                FuncoesView().tag(0)
                PartidasView().tag(1)
                ConfigView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            VStack {
                Spacer()
                HStack {
                    TabButton(icon: "square.grid.2x2.fill", title: "Funções", isSelected: selectedTab == 0) { selectedTab = 0 }
                    Spacer()
                    TabButton(icon: "gamecontroller.fill", title: "Partidas", isSelected: selectedTab == 1) { selectedTab = 1 }
                    Spacer()
                    TabButton(icon: "person.fill", title: "Config", isSelected: selectedTab == 2) { selectedTab = 2 }
                }
                .padding(.horizontal, 40).padding(.vertical, 15)
                .background(Color(white: 0.1)).clipShape(Capsule())
                .padding(.horizontal, 20).padding(.bottom, 20)
            }
            
            if state.activeInjectionName != nil {
                InjectionOverlay()
            }
        }
    }
}

struct FuncoesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "tree.fill").resizable().scaledToFill().frame(height: 150).clipped().cornerRadius(16).overlay(Color.black.opacity(0.4)).padding(.horizontal)
                Text("FUNÇÕES").font(.headline.bold()).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                
                VStack(spacing: 12) {
                    CustomToggleRow(title: "Hs Cabeça", subtitle: "Neck + Side + Up", isOn: Binding(
                        get: { state.hsCabecaEnabled },
                        set: { val in state.hsCabecaEnabled = val; state.startInjection(featureName: "Hs Cabeça", isOn: val, patchName: "aimdrag_neck") }
                    ))
                    CustomToggleRow(title: "Aim Neck 90% HS", subtitle: "Neck + Chest 90%", isOn: Binding(
                        get: { state.hsCabeca90Enabled },
                        set: { val in state.hsCabeca90Enabled = val; state.startInjection(featureName: "Aim Neck 90%", isOn: val, patchName: "aimneck_90") }
                    ))
                    CustomToggleRow(title: "Hs Alto", subtitle: "Hs up head", isOn: Binding(
                        get: { state.hsAltoEnabled },
                        set: { val in state.hsAltoEnabled = val; state.startInjection(featureName: "Hs Alto", isOn: val) }
                    ))
                    CustomToggleRow(title: "Hs Peito", subtitle: "Hs Body cache", isOn: Binding(
                        get: { state.hsPeitoEnabled },
                        set: { val in state.hsPeitoEnabled = val; state.startInjection(featureName: "Hs Peito", isOn: val) }
                    ))
                    CustomToggleRow(title: "Antenna Mão", subtitle: "Antenna on Hand", isOn: Binding(
                        get: { state.antennaMaoEnabled },
                        set: { val in state.antennaMaoEnabled = val; state.startInjection(featureName: "Antenna Mão", isOn: val) }
                    ))
                }.padding(.horizontal)
            }.padding(.top, 50).padding(.bottom, 100)
        }
    }
}

struct PartidasView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("PARTIDAS").font(.headline.bold()).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                VStack(spacing: 12) {
                    CustomToggleRow(title: "Painel", subtitle: "Painel Silent", isOn: $state.painelEnabled)
                    CustomToggleRow(title: "Aimbot e Esp", subtitle: "Aimbot e ESP", isOn: $state.aimbotEspEnabled)
                    CustomToggleRow(title: "120/144 FPS", subtitle: "Desbloqueio de FPS", isOn: $state.fps144Enabled)
                }.padding(.horizontal)
                
                Text("TEXTURAS").font(.headline.bold()).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 10)
                VStack(spacing: 12) {
                    CustomToggleRow(title: "TEXTURA FREESTYLE", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA MANDELA", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA ANGELICAL + BARBA", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA 1 PASSE + GAT UNO", subtitle: "Personagem DIMITRI", isOn: .constant(false))
                }.padding(.horizontal)
            }.padding(.top, 50).padding(.bottom, 100)
        }
    }
}

struct ConfigView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 50, height: 50).foregroundStyle(.gray)
                    VStack(alignment: .leading) {
                        Text("20/11/26, 18:18").font(.caption).foregroundStyle(.gray)
                        Text(state.timeRemaining).font(.title2.bold()).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "moon.fill").padding(10).background(Color(white: 0.15)).clipShape(Circle())
                    Image(systemName: "qrcode").padding(10).background(Color(white: 0.15)).clipShape(Circle())
                }.padding(.horizontal)
                
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title)
                    VStack(alignment: .leading) {
                        Text("Status da conta").font(.caption).foregroundStyle(.gray)
                        Text("Ativo").font(.headline).foregroundStyle(.green)
                    }
                    Spacer()
                }.padding().background(Color(white: 0.1)).cornerRadius(16).padding(.horizontal)
                
                Text("LICENÇA").font(.caption.bold()).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                VStack(spacing: 1) {
                    InfoRow(icon: "key.fill", title: "Key", value: "•••••••••••••••")
                    InfoRow(icon: "calendar", title: "Validade", value: state.expiryDate)
                    InfoRow(icon: "clock.fill", title: "Tempo restante", value: state.timeRemaining)
                }.background(Color(white: 0.1)).cornerRadius(16).padding(.horizontal)
                
                Text("DISPOSITIVO").font(.caption.bold()).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal).padding(.top, 10)
                VStack(spacing: 1) {
                    InfoRow(icon: "iphone", title: "Modelo", value: state.deviceModel)
                    InfoRow(icon: "gear", title: "iOS", value: state.deviceiOS)
                    HStack {
                        Image(systemName: "checkmark.shield.fill").foregroundStyle(.gray).frame(width: 20)
                        Text("Compatibilidade").foregroundStyle(.gray)
                        Spacer()
                        Text("Compatível").foregroundStyle(.green)
                    }.padding().background(Color(white: 0.1))
                }.cornerRadius(16).padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button("Copiar key") {}.frame(maxWidth: .infinity).padding().background(Color(white: 0.15)).foregroundStyle(.white).cornerRadius(16)
                    Button("Loja oficial") {}.frame(maxWidth: .infinity).padding().background(Color(white: 0.15)).foregroundStyle(.white).cornerRadius(16)
                }.padding(.horizontal).padding(.top, 20)
            }.padding(.top, 50).padding(.bottom, 100)
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
                Text(title).font(.caption2)
            }.foregroundStyle(isSelected ? .white : .gray)
        }
    }
}

struct CustomToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.bold()).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green)
        }.padding().background(Color(white: 0.1)).cornerRadius(16)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.gray).frame(width: 20)
            Text(title).foregroundStyle(.gray)
            Spacer()
            Text(value).foregroundStyle(.white)
        }.padding().background(Color(white: 0.1))
    }
}
