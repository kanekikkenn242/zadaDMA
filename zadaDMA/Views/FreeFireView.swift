import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Free Fire").font(.headline).foregroundColor(.white).padding(.top, 40)
                
                HStack {
                    Image(systemName: "flame.fill").resizable().frame(width: 32, height: 32).foregroundColor(.orange)
                        .padding(8).background(Color.orange.opacity(0.2)).cornerRadius(12)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Free Fire").font(.headline).foregroundColor(.white)
                            Text("NORMAL").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.purple).cornerRadius(4)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Activo").font(.caption).foregroundColor(.green)
                            Text("120 FPS").font(.caption).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color(white: 0.2)).cornerRadius(4)
                            Text("EN VIVO").font(.caption).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color(white: 0.2)).cornerRadius(4)
                        }
                    }
                    Spacer()
                    Text("23h 49m").font(.caption).foregroundColor(.gray)
                }
                .padding().background(Color(white: 0.1)).cornerRadius(16).padding(.horizontal)
                
                HStack {
                    ActionButton(icon: "scope", title: "Aimbot", isActive: true)
                    ActionButton(icon: "cube", title: "Holograma", isActive: false)
                    ActionButton(icon: "wrench", title: "Skin", isActive: false)
                }.padding(.horizontal)
                
                HStack {
                    SecondaryButton(icon: "rectangle.inset.filled", title: "Aimbot Caché", isActive: false)
                    SecondaryButton(icon: "person.crop.circle", title: "Aimbot Avatar", isActive: true)
                }.padding(.horizontal)
                
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
            Image(systemName: icon)
            Text(title).font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isActive ? .white : .gray)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(isActive ? Color(white: 0.2) : Color(white: 0.1))
        .cornerRadius(20)
    }
}

struct SecondaryButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isActive ? .white : .gray)
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(isActive ? Color(white: 0.15) : Color.clear)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.2), lineWidth: 1))
    }
}

struct FeatureToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: "scope").font(.title2).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                Text("Seguro").font(.system(size: 10, weight: .bold)).foregroundColor(.green)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.green.opacity(0.3), lineWidth: 1))
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.9)
        }
        .padding(16).background(Color(white: 0.1)).cornerRadius(16)
    }
}
