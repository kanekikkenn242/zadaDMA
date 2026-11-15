import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Free Fire").font(.system(size: 18, weight: .bold)).foregroundColor(.white).padding(.top, 20)
                
                // Karta e lartë
                HStack {
                    Image(systemName: "flame.fill").resizable().frame(width: 24, height: 24).foregroundColor(.orange)
                        .padding(10).background(Color.orange.opacity(0.2)).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Free Fire").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            Text("NORMAL").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.purple).cornerRadius(4)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Activo").font(.system(size: 12)).foregroundColor(.green)
                        }
                    }
                    Spacer()
                    Text("23h 49m").font(.system(size: 12)).foregroundColor(.gray)
                }
                .frame(height: 70) // Lartësi fikse
                .padding(.horizontal, 16)
                .background(Color(white: 0.1)).cornerRadius(16).padding(.horizontal)
                
                // Butonat e lartë
                HStack(spacing: 12) {
                    ActionButton(icon: "scope", title: "Aimbot", isActive: true)
                    ActionButton(icon: "cube", title: "Holograma", isActive: false)
                    ActionButton(icon: "wrench", title: "Skin", isActive: false)
                }.padding(.horizontal)
                
                // Toggle-at
                VStack(spacing: 12) {
                    FeatureToggleRow(title: "AIM PECHO 70%", isOn: Binding(
                        get: { state.aimPeitoEnabled },
                        set: { state.toggleAimPeito($0) }
                    ))
                    FeatureToggleRow(title: "AIMBOT DRAG", isOn: $state.aimbotDragEnabled)
                }.padding(.horizontal)
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14))
            Text(title).font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isActive ? .white : .gray)
        .frame(maxWidth: .infinity)
        .frame(height: 44) // Lartësi fikse
        .background(isActive ? Color(white: 0.2) : Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct FeatureToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: "scope").font(.system(size: 20)).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("Seguro").font(.system(size: 10, weight: .bold)).foregroundColor(.green)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.8) // Zvogëlo toggle-in
        }
        .padding(.horizontal, 16)
        .frame(height: 64) // Lartësi fikse
        .background(Color(white: 0.1)).cornerRadius(16)
    }
}
