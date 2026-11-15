import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        TabView {
            HomeTab().tabItem { Label("Inicio", systemImage: "house.fill") }
            FreeFireTab().tabItem { Label("Free Fire", systemImage: "gamecontroller.fill") }
            ProfileTab().tabItem { Label("Perfil", systemImage: "person.crop.circle") }
            SupportTab().tabItem { Label("Soporte", systemImage: "questionmark.circle") }
        }
        .accentColor(.white)
        .preferredColorScheme(.dark)
    }
}

struct HomeTab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Estado del dispositivo").foregroundStyle(.gray).frame(maxWidth: .infinity, alignment: .leading).padding()
                VStack(spacing: 1) {
                    infoRow(icon: "iphone", title: "Modelo de hardware", value: "iPhone17,5")
                    infoRow(icon: "gear", title: "iOS Version", value: "27.2.0 (24B508)")
                    infoRow(icon: "checkmark.shield.fill", title: "Compatibilidad de exploit", value: "Compatible", valueColor: .green)
                }
                .background(Color(white: 0.1))
                .cornerRadius(12)
                .padding()
                Spacer()
            }
        }
    }
    
    private func infoRow(icon: String, title: String, value: String, valueColor: Color = .gray) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.white).frame(width: 30)
            Text(title).foregroundStyle(.white)
            Spacer()
            Text(value).foregroundStyle(valueColor)
        }
        .padding()
        .background(Color(white: 0.05))
    }
}

struct FreeFireTab: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    // Karta e lartë (Free Fire)
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(.orange).font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text("Free Fire").font(.headline).foregroundStyle(.white)
                            Text("NORMAL  •  Activo").font(.caption).foregroundStyle(.green)
                        }
                        Spacer()
                        Text("120 FPS").font(.caption2).padding(4).background(Color.blue).cornerRadius(4)
                    }
                    .padding().background(Color(white: 0.1)).cornerRadius(12)
                    
                    // Butonat
                    HStack {
                        buttonIcon("Aimbot", icon: "scope")
                        buttonIcon("Holograma", icon: "hexagon")
                        buttonIcon("Skin", icon: "paintbrush")
                    }
                    
                    // Toggle-at (Aim Pecho dhe Drag)
                    VStack(spacing: 1) {
                        toggleRow(title: "AIM PECHO 70%", subtitle: "Seguro", isOn: Binding(
                            get: { state.isAimChestEnabled },
                            set: { state.toggleAimChest($0) }
                        ))
                        
                        toggleRow(title: "AIMBOT DRAG", subtitle: "Seguro", isOn: $state.isAimDragEnabled)
                    }
                    .background(Color(white: 0.1)).cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Free Fire")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func buttonIcon(_ title: String, icon: String) -> some View {
        VStack {
            Image(systemName: icon).font(.title2).foregroundStyle(.white)
            Text(title).font(.caption).foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(white: 0.15)).cornerRadius(10)
    }
    
    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: "scope").foregroundStyle(.white)
            VStack(alignment: .leading) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.green)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding()
        .background(Color(white: 0.05))
    }
}

struct ProfileTab: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill").resizable().frame(width: 80, height: 80).foregroundStyle(.white)
                Text("bnxyung7").font(.title2).bold().foregroundStyle(.white)
                Text("Pro").font(.caption).padding(.horizontal, 8).padding(.vertical, 4).background(Color.green).cornerRadius(4).foregroundStyle(.black)
                
                VStack(spacing: 1) {
                    infoRow(icon: "key.fill", title: "Clave", value: state.licenseKey)
                    infoRow(icon: "clock.fill", title: "Tiempo restante", value: state.timeRemaining)
                    infoRow(icon: "iphone", title: "UDID", value: state.udid)
                }
                .background(Color(white: 0.1)).cornerRadius(12)
                
                Button("Cerrar sesión") {
                    exit(0)
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.red.opacity(0.2)).foregroundStyle(.red).cornerRadius(10)
                
                Spacer()
            }.padding()
        }
    }
    
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.gray).frame(width: 20)
            Text(title).foregroundStyle(.gray)
            Spacer()
            Text(value).foregroundStyle(.white).font(.system(.caption, design: .monospaced))
            Image(systemName: "doc.on.doc").foregroundStyle(.gray)
        }
        .padding().background(Color(white: 0.05))
    }
}

struct SupportTab: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Soporte Técnico").foregroundStyle(.gray)
        }
    }
}
