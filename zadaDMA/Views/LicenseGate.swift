import SwiftUI

struct LicenseGate: View {
    @EnvironmentObject var state: AppState
    @State private var keyInput = ""
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                Text("dope")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                
                VStack(spacing: 6) {
                    Text("Entre para continuar")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Digite sua licença.")
                        .font(.system(size: 14))
                        .foregroundStyle(.gray)
                }
                
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.gray)
                            .font(.system(size: 14))
                        TextField("KEY-XXXX-XXXXX", text: $keyInput)
                            .foregroundStyle(.white)
                            .font(.system(size: 15))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color(white: 0.12))
                    .cornerRadius(14)
                    
                    if showError {
                        Text("Chave inválida.")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button {
                        let success = state.unlockApp(key: keyInput)
                        if !success { showError = true }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Entrar")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(white: 0.7))
                        .foregroundStyle(.black)
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 32)
                
                Button("Precisa de uma key? Clique aqui") {}
                    .font(.system(size: 13))
                    .foregroundStyle(.gray)
                
                Spacer()
            }
        }
    }
}
