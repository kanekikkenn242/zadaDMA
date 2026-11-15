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
                        Text("\(state.activeInjectionName ?? "") foi injetada.").font(.system(size: 13)).foregroundStyle(.gray)
                        Button("OK") { state.closeInjection() }
                            .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color(white: 0.2)).foregroundStyle(.white).cornerRadius(14).padding(.top, 8)
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).padding(40)
                    
                } else if let error = state.injectionError {
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 56)).foregroundStyle(.red)
                        Text("Falha na Injeção").font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        Text(error).font(.system(size: 13)).foregroundStyle(.gray).multilineTextAlignment(.center)
                        Button("Fechar") { state.closeInjection() }
                            .font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48)
                            .background(Color(white: 0.2)).foregroundStyle(.white).cornerRadius(14).padding(.top, 8)
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).padding(40)
                    
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(.green).font(.system(size: 20))
                            Text("Injetando \(state.activeInjectionName ?? "")").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        }
                        Text("Não feche o app enquanto a injeção está em andamento.").font(.system(size: 12)).foregroundStyle(.gray)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepRow(text: "Iniciando injeção...", isActive: state.injectionStep >= 1)
                            StepRow(text: "Verificando compatibilidade...", isActive: state.injectionStep >= 2)
                            StepRow(text: "Preparando os componentes...", isActive: state.injectionStep >= 3)
                            StepRow(text: "Aplicando a função...", isActive: state.injectionStep >= 4)
                        }.padding(.top, 10)
                        Spacer()
                    }.padding(24).background(Color(white: 0.1)).cornerRadius(22).frame(height: 240).padding(40)
                }
            }
        }
    }
}

struct StepRow: View {
    let text: String
    let isActive: Bool
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle").foregroundStyle(isActive ? .green : .gray).font(.system(size: 13))
            Text(text).font(.system(size: 13)).foregroundStyle(isActive ? .white : .gray)
        }
    }
}
