import SwiftUI
struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.08, green: 0.04, blue: 0.18)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 72, weight: .bold)).foregroundStyle(.purple)
                Text("zadaDMA").font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("patch motor").foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { state.enterDashboard() } label: {
                    Text("Enter").frame(maxWidth: .infinity).padding()
                        .background(Color.purple).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }.padding(.horizontal, 24)
                Text("Free Fire only · com.dts.freefireth / freefiremax")
                    .font(.caption).foregroundStyle(.white.opacity(0.4)).padding(.bottom, 24)
            }
        }
    }
}
