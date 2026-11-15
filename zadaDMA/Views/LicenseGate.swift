import SwiftUI

struct LicenseGate: View {
    @EnvironmentObject var state: AppState
    @State private var keyInput = ""
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 70)).foregroundStyle(.white)
                
                Text("zadaDMA").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white)
                
                VStack(spacing: 16) {
                    TextField("Clave de Acceso", text: $keyInput)
                        .padding()
                        .background(Color(white: 0.1))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    
                    if let error = errorMessage {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                    
                    Button {
                        validateKey()
                    } label: {
                        if isLoading { ProgressView().tint(.black) }
                        else { Text("Activar").bold() }
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.white).foregroundStyle(.black)
                    .cornerRadius(10)
                    .disabled(isLoading)
                }
                .padding(.horizontal, 30)
                Spacer()
            }
        }
    }

    private func validateKey() {
        isLoading = true
        errorMessage = nil
        
        // Simulim i serverit tënd: pranon çdo çelës që fillon me "ZTOT" ose "ZDMA"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if keyInput.count > 5 {
                isLoading = false
                state.unlockApp(key: keyInput)
            } else {
                errorMessage = "Clave inválida."
                isLoading = false
            }
        }
    }
}
