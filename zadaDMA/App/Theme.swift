import SwiftUI

enum Theme {
    static let background = Color(red: 0.05, green: 0.06, blue: 0.08)
    static let surface = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let surfaceRaised = Color(red: 0.13, green: 0.14, blue: 0.18)
    static let accent = Color(red: 0.36, green: 0.86, blue: 0.62)
    static let danger = Color(red: 0.92, green: 0.36, blue: 0.36)
    static let muted = Color(red: 0.55, green: 0.58, blue: 0.64)
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundColor(Theme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}
