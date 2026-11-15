import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(state.selectedGame).font(.title2.bold()).foregroundColor(.white).padding(.top, 20)
                
                HStack(spacing: 12) {
                    CategoryButton(icon: "scope", title: "Aimbot", isActive: state.selectedCategory == "Aimbot") { state.selectedCategory = "Aimbot" }
                    CategoryButton(icon: "cube", title: "Holograma", isActive: state.selectedCategory == "Holograma") { state.selectedCategory = "Holograma" }
                    CategoryButton(icon: "wrench", title: "Skin", isActive: state.selectedCategory == "Skin") { state.selectedCategory = "Skin" }
                }.padding(.horizontal)
                
                VStack(spacing: 12) {
                    if state.selectedCategory == "Aimbot" {
                        // AIM PECHO - Skedari 70%
                        FeatureToggleRow(title: "AIM PECHO 70%", isOn: Binding(
                            get: { state.aimPeitoEnabled },
                            set: { val in 
                                state.aimPeitoEnabled = val
                                state.toggleFeature("AIM PECHO", isOn: val, patchFile: "aimdrag_neck") 
                            }
                        ))
                        
                        // AIMBOT DRAG - Skedari i ri
                        FeatureToggleRow(title: "AIMBOT DRAG", isOn: Binding(
                            get: { state.aimbotDragEnabled },
                            set: { val in 
                                state.aimbotDragEnabled = val
                                state.toggleFeature("AIMBOT DRAG", isOn: val, patchFile: "aimbot_drag") 
                            }
                        ))
                    } else if state.selectedCategory == "Holograma" {
                        FeatureToggleRow(title: "HOLOGRAMA PURPLE", isOn: Binding(
                            get: { state.hologramEnabled },
                            set: { val in state.hologramEnabled = val; state.toggleFeature("HOLOGRAMA", isOn: val) }
                        ))
                    } else if state.selectedCategory == "Skin" {
                        FeatureToggleRow(title: "SKIN VIP", isOn: Binding(
                            get: { state.skinEnabled },
                            set: { val in state.skinEnabled = val; state.toggleFeature("SKIN", isOn: val) }
                        ))
                    }
                }.padding(.horizontal)
                
                // ... log area
            }
        }
    }
}
