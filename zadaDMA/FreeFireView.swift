import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("1.40")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding(.horizontal)
                
                Text("Free Fire MAX")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.top, 8)
                
                HStack {
                    Text("Listo para cargar")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Spacer()
                    Text("2 EN VIVO")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.appGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appGreen.opacity(0.15))
                        .cornerRadius(6)
                    Text("5d 12h")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                HStack(spacing: 12) {
                    CategoryButton(icon: "scope", title: "Aimbot", isActive: state.selectedCategory == "Aimbot") { state.selectedCategory = "Aimbot" }
                    CategoryButton(icon: "cube", title: "Holograma", isActive: state.selectedCategory == "Holograma") { state.selectedCategory = "Holograma" }
                    CategoryButton(icon: "wrench", title: "Skin", isActive: state.selectedCategory == "Skin") { state.selectedCategory = "Skin" }
                }.padding(.horizontal)
                
                VStack(spacing: 12) {
                    if state.selectedCategory == "Aimbot" {
                        FeatureToggleRow(title: "AIM PECHO 70%", isOn: Binding(
                            get: { state.aimPeitoEnabled },
                            set: { val in 
                                state.aimPeitoEnabled = val
                                state.toggleFeature("AIM PECHO", isOn: val, patchFile: "aimdrag_neck") 
                            }
                        ))
                        
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
                            set: { val in 
                                state.hologramEnabled = val
                                state.toggleFeature("HOLOGRAMA", isOn: val, patchFile: "hologram") 
                            }
                        ))
                    } else if state.selectedCategory == "Skin" {
                        FeatureToggleRow(title: "SKIN VIP", isOn: Binding(
                            get: { state.skinEnabled },
                            set: { val in 
                                state.skinEnabled = val
                                state.toggleFeature("SKIN", isOn: val, patchFile: "skin") 
                            }
                        ))
                    }
                }.padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Logs").font(.caption).foregroundColor(.gray)
                    ForEach(state.patchLog.suffix(3), id: \.self) { log in
                        Text(log).font(.system(size: 10, design: .monospaced)).foregroundColor(.green)
                    }
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.black).cornerRadius(12).padding(.horizontal)
            }
        }
    }
}

struct CategoryButton: View {
    let icon: String; let title: String; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(title).font(.system(size: 14)) }
            .foregroundColor(isActive ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(isActive ? Color(white: 0.2) : Color.appCard).cornerRadius(12)
        }
    }
}

struct FeatureToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: "scope").font(.title2).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("Seguro").font(.system(size: 10, weight: .bold)).foregroundColor(.green)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.8)
        }
        .padding(.horizontal)
        .frame(height: 64)
        .background(Color.appCard)
        .cornerRadius(16)
    }
}
