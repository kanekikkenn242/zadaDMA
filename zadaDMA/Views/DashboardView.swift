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
                    // 1. Hs Cabeça standard
                    CustomToggleRow(title: "Hs Cabeça", subtitle: "Neck + Side + Up", isOn: Binding(
                        get: { state.hsCabecaEnabled },
                        set: { val in 
                            state.hsCabecaEnabled = val; 
                            state.startInjection(featureName: "Hs Cabeça", isOn: val, patchName: "aimdrag_neck") 
                        }
                    ))
                    
                    // 2. I RI: Aim Neck 90% HS
                    CustomToggleRow(title: "Aim Neck 90% HS", subtitle: "Neck + Chest 90%", isOn: Binding(
                        get: { state.hsCabeca90Enabled },
                        set: { val in 
                            state.hsCabeca90Enabled = val; 
                            state.startInjection(featureName: "Aim Neck 90%", isOn: val, patchName: "aimneck_90") 
                        }
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
                }
                .padding(.horizontal)
            }
            .padding(.top, 50).padding(.bottom, 100)
        }
    }
}

// (Pjesa tjetër e skedarit: PartidasView, ConfigView, TabButton, CustomToggleRow, InfoRow mbeten të njëjta si në mesazhin e mëparshëm)
