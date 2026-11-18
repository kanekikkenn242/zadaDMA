import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step = 0

    private let pages: [(title: String, body: String, symbol: String)] = [
        ("Pair once",
         "Drop in the pairing record this device already trusts, then point the tunnel at the loopback address your VPN publishes.",
         "link"),
        ("Open the tunnel",
         "zadaDMA asks lockdownd for a listener, wraps it in the PSK tunnel and speaks AFC to the filesystem — no jailbreak, no injection.",
         "arrow.triangle.branch"),
        ("Swap the asset",
         "Pick a patch. The current asset is copied out first, the replacement is written and read back, and you can restore the original in one tap.",
         "arrow.left.arrow.right"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)

            Image(systemName: pages[step].symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundColor(Theme.accent)
                .padding(.bottom, 24)

            Text(pages[step].title)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)

            Text(pages[step].body)
                .font(.system(size: 15))
                .foregroundColor(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 8)

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Theme.accent : Theme.surfaceRaised)
                        .frame(width: index == step ? 22 : 8, height: 8)
                }
            }
            .padding(.top, 28)

            Spacer()

            Button {
                if step + 1 < pages.count {
                    withAnimation(.easeInOut(duration: 0.2)) { step += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(step + 1 < pages.count ? "Continue" : "Open dashboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
