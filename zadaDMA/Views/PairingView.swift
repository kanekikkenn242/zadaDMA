import SwiftUI

struct PairingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var pairing = PairingController.shared
    @State private var code = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Pairing Developer Mode")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            VStack(spacing: 10) {
                Text("Kodi 6-shifror:")
                    .font(.headline)
                
                TextField("Përshkruaj kodin", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 250)
                
                Button("Përdor kodin") {
                    pairing.startPairing(pin: code) { success in
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(code.count != 6)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: pairing.pairingStatus == "Paired" ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    Text("\(pairing.pairingStatus)")
                        .font(.subheadline)
                }
                
                HStack {
                    Image(systemName: pairing.currentPin.isEmpty ? "lock" : "number")
                    Text("Kodi aktiv: \(pairing.currentPin.isEmpty ? "Jo" : pairing.currentPin)")
                        .font(.caption)
                }
            }
            .padding(.horizontal)
            
            Button("Bete") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 30)
        }
    }
}