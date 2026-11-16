import SwiftUI

struct PairingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var pairing = PairingController.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Pairing Developer Mode")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 20)

            VStack(spacing: 10) {
                Text("PIN:")
                    .font(.headline)

                Text(pairing.currentPin.isEmpty ? "— — — — — —" : pairing.currentPin)
                    .font(.system(size: 34, weight: .heavy, design: .monospaced))
                    .foregroundColor(pairing.currentPin.isEmpty ? .gray : .orange)

                Text("Settings → Privacy & Security → Developer Mode → Pair with \"zadaDMA\"")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)

                if pairing.isPairing {
                    Button("Stop Pairing") {
                        pairing.stopPairing()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Start Pairing") {
                        pairing.startPairing { _ in }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: pairing.hasPairingFile ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    Text(pairing.pairingStatus)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)

            Button("Mbylle") {
                dismiss()
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 30)
        }
    }
}
