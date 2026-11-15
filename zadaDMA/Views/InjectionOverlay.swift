import SwiftUI

struct InjectionOverlay: View {
    @EnvironmentObject var state: AppState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack {
                if state.injectionSuccess {
                    // Success View
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        
                        Text("Injetado com sucesso")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        
                        Text("\(state.activeInjectionName ?? "") foi injetada.")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                        
                        Button("OK") {
                            state.closeInjection()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(white: 0.2))
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                        .padding(.top, 10)
                    }
                    .padding(24)
                    .background(Color(white: 0.1))
                    .cornerRadius(24)
                    .padding(40)
                    
                } else {
                    // Loading View
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(.green)
                            Text("Injetando \(state.activeInjectionName ?? "")")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        
                        Text("Não feche o app enquanto a injeção está em andamento.")
                            .font(.caption)
                            .foregroundStyle(.gray)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            StepRow(text: "Iniciando injeção de \(state.activeInjectionName ?? "")...", isActive: state.injectionStep >= 1)
                            StepRow(text: "Verificando compatibilidade do dispositivo...", isActive: state.injectionStep >= 2)
                            StepRow(text: "Preparando os componentes da função...", isActive: state.injectionStep >= 3)
                            StepRow(text: "Aplicando a função...", isActive: state.injectionStep >= 4)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding(24)
                    .background(Color(white: 0.1))
                    .cornerRadius(24)
                    .frame(height: 300)
                    .padding(40)
                }
            }
        }
    }
}

struct StepRow: View {
    let text: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isActive ? "checkmark" : "circle")
                .foregroundStyle(isActive ? .green : .gray)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(isActive ? .white : .gray)
        }
    }
}
