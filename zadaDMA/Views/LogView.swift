import SwiftUI

struct LogView: View {
    @ObservedObject var log: AppLog

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    if log.entries.isEmpty {
                        Text("Nothing yet.")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.muted)
                    }

                    ForEach(log.entries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(Self.formatter.string(from: entry.date))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.muted)
                            Text(entry.message)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(tint(entry.level))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") { log.clear() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func tint(_ level: LogLevel) -> Color {
        switch level {
        case .info: return Color.white.opacity(0.82)
        case .ok: return Theme.accent
        case .warn: return Color.orange
        case .error: return Theme.danger
        }
    }
}
