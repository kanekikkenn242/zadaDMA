import SwiftUI

struct FreeFireView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(state.selectedGame).font(.headline).foregroundColor(.white).padding(.top, 20)
                
                HStack {
                    Image(systemName: "flame.fill").resizable().frame(width: 24, height: 24).foregroundColor(.orange).padding(10).background(Color.orange.opacity(0.2)).cornerRadius(12)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(state.selectedGame).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            Text("NORMAL").font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color.purple).cornerRadius(4)
                        }
                        HStack(spacing: 8) {
                            Circle().fill(.green).frame(width: 6, height: 6)
                            Text("Activo").font(.system(size: 12)).foregroundColor(.green)
                            Text("120 FPS").font(.system(size: 10)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Color(white: 0.2)).cornerRadius(4)
                        }
                    }
                    Spacer()
                    Text("23h 49m").font(.caption).foregroundColor(.gray)
                }.padding(.horizontal).background(Color.appCard).cornerRadius(16).padding(.horizontal)
                
                HStack(spacing: 12) {
                    ActionButton(icon: "scope", title: "Aimbot", isActive: true)
                    ActionButton(icon: "cube", title: "Holograma", isActive: false)
                    ActionButton(icon: "wrench", title: "Skin", isActive: false)
                }.padding(.horizontal)
                
                HStack(spacing: 12) {
                    SecondaryButton(icon: "rectangle.inset.filled", title: "Aimbot Caché", isActive: false)
                    SecondaryButton(icon: "person.crop.circle", title: "Aimbot Avatar", isActive: true)
                }.padding(.horizontal)
                
                VStack(spacing: 12) {
                    FeatureToggleRow(title: "AIM PECHO 70%", isOn: $state.aimPeitoEnabled)
                    FeatureToggleRow(title: "AIMBOT DRAG", isOn: $state.aimbotDragEnabled)
                }.padding(.horizontal)
            }
        }
    }
}

struct ActionButton: View {
    let icon: String; let title: String; let isActive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon); Text(title).font(.system(size: 14))
        }.foregroundColor(isActive ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(isActive ? Color(white: 0.2) : Color.appCard).cornerRadius(12)
    }
}

struct SecondaryButton: View {
    let icon: String; let title: String; let isActive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon); Text(title).font(.system(size: 14))
        }.foregroundColor(isActive ? .white : .gray).frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.appCard).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isActive ? Color(white: 0.3) : Color.clear, lineWidth: 1))
    }
}

struct FeatureToggleRow: View {
    let title: String; @Binding var isOn: Bool
    var body: some View {
        HStack {
            Image(systemName: "scope").font(.title2).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("Seguro").font(.system(size: 10, weight: .bold)).foregroundColor(.green).padding(.horizontal, 6).padding(.vertical, 2).background(Color.green.opacity(0.1)).cornerRadius(4)
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(.green).scaleEffect(0.8)
        }.padding(.horizontal).frame(height: 64).background(Color.appCard).cornerRadius(16)
    }
}
