import SwiftUI

extension Color {
    static let appOrange = Color(red: 1.0, green: 0.478, blue: 0.0)
    static let appCard = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let appBackground = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let appSecondary = Color(red: 0.18, green: 0.18, blue: 0.20)
    static let appGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let appRed = Color(red: 0.9, green: 0.3, blue: 0.3)
}

struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.appOrange)
            .cornerRadius(14)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct DarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(white: 0.15))
            .cornerRadius(14)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.appCard)
            .cornerRadius(16)
    }
}

extension View {
    func cardStyle() -> some View { self.modifier(CardModifier()) }
}
