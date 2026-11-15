import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedTab) {
                FuncoesView().tag(0)
                PartidasView().tag(1)
                ConfigView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Floating Tab Bar
            HStack {
                TabButton(icon: "square.grid.2x2.fill", title: "Funções", isSelected: selectedTab == 0) { selectedTab = 0 }
                Spacer()
                TabButton(icon: "gamecontroller.fill", title: "Partidas", isSelected: selectedTab == 1) { selectedTab = 1 }
                Spacer()
                TabButton(icon: "person.fill", title: "Config", isSelected: selectedTab == 2) { selectedTab = 2 }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(white: 0.1))
            .clipShape(Capsule())
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
            
            if state.activeInjectionName != nil {
                InjectionOverlay()
            }
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
            .foregroundStyle(isSelected ? .white : .gray)
            .frame(width: 60)
        }
    }
}

struct FuncoesView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ZStack {
                    Image(systemName: "tree.fill")
                        .resizable().scaledToFill().frame(height: 130).clipped().foregroundStyle(.gray.opacity(0.3))
                    Color.black.opacity(0.4)
                    Text("zadaDMA").font(.system(size: 22, weight: .bold)).foregroundStyle(.white).opacity(0.5)
                }
                .frame(height: 130).cornerRadius(14).padding(.horizontal, 16)
                
                Text("FUNÇÕES").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                
                VStack(spacing: 8) {
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
                }.padding(.horizontal, 16)
                Spacer().frame(height: 100)
            }.padding(.top, 20)
        }
    }
}

struct PartidasView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("PARTIDAS").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16)
                VStack(spacing: 8) {
                    CustomToggleRow(title: "Painel", subtitle: "Painel Silent", isOn: $state.painelEnabled)
                    CustomToggleRow(title: "Aimbot e Esp", subtitle: "Aimbot e ESP", isOn: $state.aimbotEspEnabled)
                    CustomToggleRow(title: "120/144 FPS", subtitle: "Desbloqueio de FPS", isOn: $state.fps144Enabled)
                }.padding(.horizontal, 16)
                
                Text("TEXTURAS").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 10)
                VStack(spacing: 8) {
                    CustomToggleRow(title: "TEXTURA FREESTYLE", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA MANDELA", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA ANGELICAL + BARBA", subtitle: "Personagem ALOK", isOn: .constant(false))
                    CustomToggleRow(title: "TEXTURA 1 PASSE + GAT UNO", subtitle: "Personagem DIMITRI", isOn: .constant(false))
                }.padding(.horizontal, 16)
                Spacer().frame(height: 100)
            }.padding(.top, 30)
        }
    }
}

struct ConfigView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill").resizable().frame(width: 44, height: 44).foregroundStyle(.gray)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("20/11/26, 18:18").font(.system(size: 12)).foregroundStyle(.gray)
                        Text(state.timeRemaining).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "moon.fill").font(.system(size: 16)).padding(10).background(Color(white: 0.15)).clipShape(Circle())
                    Image(systemName: "qrcode").font(.system(size: 16)).padding(10).background(Color(white: 0.15)).clipShape(Circle())
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
                    Text("LICENÇA").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    VStack(spacing: 1) {
                        InfoRow(icon: "key.fill", title: "Key", value: "•••••••••••••••")
                        InfoRow(icon: "calendar", title: "Validade", value: state.expiryDate)
                        InfoRow(icon: "clock.fill", title: "Tempo restante", value: state.timeRemaining)
                    }.cornerRadius(14)
                }.padding(.horizontal, 16)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("DISPOSITIVO").font(.system(size: 11, weight: .bold)).foregroundStyle(.gray)
                    VStack(spacing: 1) {
                        InfoRow(icon: "iphone", title: "Modelo", value: state.deviceModel)
                        InfoRow(icon: "gear", title: "iOS", value: state.deviceiOS)
                        HStack {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(.gray).frame(width: 18)
                            Text("Compatibilidade").font(.system(size: 14)).foregroundStyle(.gray)
                            Spacer()
                            Text("Compatível").font(.system(size: 14)).foregroundStyle(.green)
                        }.padding(14).background(Color(white: 0.1))
                    }.cornerRadius(14)
                }.padding(.horizontal, 16)
                
                VStack(spacing: 10) {
                    Button("Copiar key") {}.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48).background(Color(white: 0.15)).foregroundStyle(.white).cornerRadius(14)
                    Button("Loja oficial") {}.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48).background(Color(white: 0.15)).foregroundStyle(.white).cornerRadius(14)
                }.padding(.horizontal, 16).padding(.top, 10)
                Spacer().frame(height: 100)
            }
        }
    }
}

struct CustomToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.gray)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.85)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(Color(white: 0.1)).cornerRadius(14)
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.gray).frame(width: 18).font(.system(size: 13))
            Text(title).font(.system(size: 14)).foregroundStyle(.gray)
            Spacer()
            Text(value).font(.system(size: 14)).foregroundStyle(.white)
        }.padding(14).background(Color(white: 0.1))
    }
}
