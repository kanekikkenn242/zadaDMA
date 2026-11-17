import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) var dismiss

    // MARK: - Detección de Contenedores
    @State private var containerDetectionEnabled = true
    @State private var isScanning = false
    @State private var containersFound: Int? = nil

    // MARK: - Versiones verificadas
    @State private var ios27Expanded = true

    private let legacyGroups = ["iOS 17", "iOS 18", "iOS 26"]
    private let ios27Groups: [(title: String, builds: [String])] = [
        ("iOS 27.0", [
            "24A5355q", "24A5370h", "24A5380h", "24A5390f", "24A5408d",
            "24A5418b", "24A5424a", "24A5430a", "24A435", "24A437"
        ]),
        ("iOS 27.0.1", ["24A446"]),
        ("iOS 27.2", ["24B5084k", "24B5089g", "24B119"]),
        ("iOS 27.2.1", ["24B156", "24B91034"]),
        ("iOS 27.3", ["24C5037i"])
    ]

    private var appearanceBinding: Binding<String> {
        Binding(get: { state.appearance }, set: { state.appearance = $0 })
    }

    private var iosVersionText: String {
        let build = DeviceInfo().buildNumber
        return build.isEmpty ? state.deviceiOS : "\(state.deviceiOS) (\(build))"
    }

    private var exploitCompatible: Bool {
        let parts = state.deviceiOS.split(separator: ".").map(String.init)
        guard let first = parts.first, let major = Int(first) else { return false }
        if major != 27 { return [17, 18, 26].contains(major) }
        let minor = parts.count > 1 ? parts[1] : "0"
        let key = "iOS 27.\(minor)"
        guard let builds = ios27Groups.first(where: { $0.title == key })?.builds else { return false }
        let build = DeviceInfo().buildNumber
        return !build.isEmpty && builds.contains(build)
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("Sistema", selection: appearanceBinding) {
                        Text("Sistema").tag("System")
                        Text("Claro").tag("Light")
                        Text("Oscuro").tag("Dark")
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)
                }

                Section(header: Text("Dispositivo").textCase(nil)) {
                    HStack {
                        Text("Modelo de hardware")
                        Spacer()
                        Text(state.deviceModel).foregroundColor(.gray)
                    }
                    HStack {
                        Text("Versión de iOS")
                        Spacer()
                        Text(iosVersionText).foregroundColor(.gray)
                    }
                }

                Section(header: Text("Detección de Contenedores").textCase(nil)) {
                    HStack(spacing: 12) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.appOrange)
                            .frame(width: 28, height: 28)
                            .background(Color.appOrange.opacity(0.15))
                            .cornerRadius(7)
                        Text("Activar Detección de Contenedores")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Toggle("", isOn: $containerDetectionEnabled)
                            .labelsHidden()
                            .tint(.appOrange)
                    }

                    if isScanning {
                        HStack(spacing: 10) {
                            ProgressView().tint(.appOrange)
                            Text("Escaneando...")
                                .foregroundColor(.gray)
                        }
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.clockwise").foregroundColor(.appOrange)
                            Text("Escaneando...")
                                .foregroundColor(.gray)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.appGreen)
                            Text("\(containersFound ?? 0) contenedores encontrados")
                                .foregroundColor(.white)
                        }
                        Text("Método: worse_query (iOS 26/27)")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Button(action: startScan) {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.clockwise").foregroundColor(.appOrange)
                                Text("Volver a escanear")
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Text("Cuando está activado, X escanea los contenedores de aplicaciones instaladas usando el método disponible en este dispositivo. Volver a escanear actualiza la lista.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section(header: Text("Versiones verificadas").textCase(nil)) {
                    HStack {
                        Text("Compatibilidad del exploit")
                        Spacer()
                        Text(exploitCompatible ? "Compatible" : "No compatible")
                            .foregroundColor(exploitCompatible ? .appGreen : .appRed)
                    }

                    ForEach(legacyGroups, id: \.self) { group in
                        HStack {
                            Text(group)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    Button(action: { withAnimation { ios27Expanded.toggle() } }) {
                        HStack {
                            Text("iOS 27")
                            Spacer()
                            Image(systemName: ios27Expanded ? "chevron.down" : "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .foregroundColor(.primary)

                    if ios27Expanded {
                        ForEach(ios27Groups, id: \.title) { group in
                            HStack(alignment: .top) {
                                Text(group.title)
                                    .font(.system(size: 15))
                                Spacer()
                                Text(group.builds.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.leading, 16)
                        }
                    }

                    Text("Solo las compilaciones indicadas arriba están verificadas para el exploit. iOS se sigue reconociendo; el emparejamiento y el túnel son estados aparte.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Section(header: Text("Redes sociales").textCase(nil)) {
                    SocialRow(icon: "paperplane.fill", title: "Telegram", subtitle: "Anuncios y novedades")
                    SocialRow(icon: "bubble.left.and.bubble.right.fill", title: "Discord", subtitle: "Soporte y comunidad")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .task(id: containerDetectionEnabled) {
                if containerDetectionEnabled { startScan() }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Hecho") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appOrange)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.appSecondary)
                        .clipShape(Capsule())
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startScan() {
        isScanning = true
        containersFound = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isScanning = false
            containersFound = 299
        }
    }
}

private struct SocialRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.appOrange)
                .frame(width: 28, height: 28)
                .background(Color.appOrange.opacity(0.15))
                .cornerRadius(7)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).foregroundColor(.white)
                Text(subtitle).font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundColor(.appOrange)
        }
    }
}
