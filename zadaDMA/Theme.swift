import SwiftUI

extension Color {
    static let appOrange = Color(red: 1.0, green: 0.478, blue: 0.0) // #FF7A00
    static let appBlack = Color.black
    static let appCard = Color(red: 0.1, green: 0.1, blue: 0.1) // #1A1A1A
    static let appGray = Color.gray.opacity(0.6)
}

struct OrangeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.appOrange)
            .cornerRadius(16)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.appCard)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}

extension View {
    func cardStyle() -> some View { self.modifier(CardModifier()) }
}
