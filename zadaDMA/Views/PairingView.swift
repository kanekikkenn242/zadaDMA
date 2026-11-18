import SwiftUI
import UniformTypeIdentifiers

struct PairingView: View {
    @EnvironmentObject private var state: AppState

    @State private var showPicker = false
    @State private var testing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                recordCard
                tunnelCard
                actionCard
            }
            .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Pairing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            DocumentPicker { url in importRecord(url) }
        }
    }

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Pairing record")

            Text(state.pairingFilePath.isEmpty
                 ? "No record imported. Export the pairing plist for this phone and open it here."
                 : state.pairingFilePath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(state.pairingFilePath.isEmpty ? Theme.muted : .white)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showPicker = true
            } label: {
                Text("Import pairing file")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var tunnelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Tunnel")

            field(title: "Host", text: Binding(
                get: { state.host },
                set: { state.host = $0; state.persist() }
            ))

            field(title: "Port", text: Binding(
                get: { state.portText },
                set: { state.portText = $0; state.persist() }
            ))

            field(title: "PIN", text: Binding(
                get: { state.pin },
                set: { state.pin = $0; state.persist() }
            ))

            Text("The port is the one LocalDevVPN forwards for the device's remote-pairing listener. The PIN is only used if the device asks for pair-setup instead of verify.")
                .font(.system(size: 11))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                test()
            } label: {
                HStack(spacing: 8) {
                    if testing {
                        ProgressView().tint(Theme.background)
                    }
                    Text(testing ? "Opening tunnel…" : "Test connection")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.background)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(state.pairingReady ? Theme.accent : Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(testing || !state.pairingReady)

            switch state.phase {
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            case .ready(let detail):
                Text(detail)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            default:
                EmptyView()
            }
        }
        .card()
    }

    private func field(title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.muted)
                .frame(width: 48, alignment: .leading)

            TextField("", text: text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .keyboardType(title == "Port" || title == "PIN" ? .numberPad : .default)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Theme.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func importRecord(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = documents.appendingPathComponent("pairing.plist")
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            state.pairingFilePath = destination.path
            state.persist()
            state.log.ok("pairing record imported")
        } catch {
            state.log.error("pairing import failed: \(error.localizedDescription)")
        }
    }

    private func test() {
        guard state.pairingReady else {
            state.log.error("pairing record and port are required")
            return
        }

        testing = true
        state.phase = .connecting

        let settings = state.settings
        let bundle = state.bundleIdentifier

        Task {
            do {
                let detail = try await Task.detached(priority: .userInitiated) {
                    try Airlift.probe(settings, bundle: bundle)
                }.value
                state.log.ok("tunnel ready — \(detail)")
                state.phase = .ready(detail)
            } catch {
                state.log.error(error.localizedDescription)
                state.phase = .failed(error.localizedDescription)
            }
            testing = false
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item, .data], asCopy: true)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}
