import SwiftUI

struct InjectionOverlay: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack {
                if state.injectionSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(.green)
                        Text("Injetado com sucesso").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Button("OK") { state.injectionName = nil }.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48).background(Color(white: 0.2)).cornerRadius(14)
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).padding(40)
                } else if let err = state.injectionError {
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 56)).foregroundStyle(.red)
                        Text("Falha na Injeção").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Text(err).font(.system(size: 12)).foregroundStyle(.gray).multilineTextAlignment(.center)
                        Button("Fechar") { state.injectionName = nil }.font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48).background(Color(white: 0.2)).cornerRadius(14)
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).padding(40)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(.green)
                            Text("Injetando \(state.injectionName ?? "")").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                        Text("Não feche o app enquanto a injeção está em andamento.").font(.system(size: 12)).foregroundStyle(.gray)
                        VStack(alignment: .leading, spacing: 10) {
                            StepRow(text: "Iniciando injeção...", active: state.injectionStep >= 1)
                            StepRow(text: "Verificando compatibilidade...", active: state.injectionStep >= 2)
                            StepRow(text: "Preparando os componentes...", active: state.injectionStep >= 3)
                            StepRow(text: "Aplicando a função...", active: state.injectionStep >= 4)
                        }.padding(.top, 10)
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).padding(40)
                }
            }
        }
    }
}

struct StepRow: View {
    let text: String, active: Bool
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle").foregroundStyle(active ? .green : .gray).font(.system(size: 12))
            Text(text).font(.system(size: 12)).foregroundStyle(active ? .white : .gray)
        }
    }
}
