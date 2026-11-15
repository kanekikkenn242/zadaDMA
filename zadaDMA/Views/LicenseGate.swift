import SwiftUI

struct LicenseGate: View {
    @EnvironmentObject var state: AppState
    @State private var keyInput = ""
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo
                Text("dope")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                VStack(spacing: 8) {
                    Text("Entre para continuar")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    Text("Digite sua licença.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                }
                
                // Fusha e inputit
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.gray)
                            .font(.system(size: 16))
                        TextField("KEY-XXXX-XXXXX", text: $keyInput)
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .medium))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }
                    .padding()
                    .background(Color(white: 0.12))
                    .cornerRadius(16)
                    
                    if showError {
                        Text("Chave inválida. Tente novamente.")
                            .foregroundStyle(.red)
                            .font(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    
                    Button {
                        let success = state.unlockApp(key: keyInput)
                        if !success { showError = true }
                    } label: {
                        HStack {
                            Text("Entrar")
                                .font(.headline)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(white: 0.6))
                        .foregroundStyle(.black)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 32)
                
                Button("Precisa de uma key? Clique aqui") {}
                    .font(.footnote)
                    .foregroundStyle(.gray)
                
                Spacer()
            }
        }
    }
}
