import Foundation
import Combine

enum LogLevel: String {
    case info, ok, warn, error
}

struct LogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let level: LogLevel
    let message: String
}

/// Single sink for everything the app reports. The patch path writes here so the
/// user can see exactly which container was touched and whether the readback held.
@MainActor
final class AppLog: ObservableObject {
    @Published private(set) var entries: [LogEntry] = []

    private let limit = 600

    func info(_ message: String) { write(.info, message) }
    func ok(_ message: String) { write(.ok, message) }
    func warn(_ message: String) { write(.warn, message) }
    func error(_ message: String) { write(.error, message) }

    func write(_ level: LogLevel, _ message: String) {
        entries.append(LogEntry(date: Date(), level: level, message: message))
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        NSLog("[zadaDMA] %@", message)
    }

    func clear() {
        entries.removeAll()
    }
}
