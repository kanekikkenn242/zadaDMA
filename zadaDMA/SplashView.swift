import SwiftUI

struct SplashView: View {
    @EnvironmentObject var state: AppState
    @Binding var showSplash: Bool
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Circle().stroke(Color.gray.opacity(0.3), lineWidth: 4).frame(width: 120, height: 120)
                Circle().trim(from: 0, to: progress).stroke(Color.appOrange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 120, height: 120).rotationEffect(.degrees(-90))
                Text("X").font(.system(size: 50, weight: .bold)).foregroundColor(.white)
            }
            .padding(.bottom, 20)
            Text("zadaDMA").font(.headline).foregroundColor(.white)
            Text(state.deviceModel).font(.caption).foregroundColor(.gray)
            Text(state.deviceiOS).font(.caption).foregroundColor(.gray)
            
            Spacer()
            
            VStack(spacing: 12) {
                Text("Want to listen to music?").font(.subheadline.bold()).foregroundColor(.white)
                HStack(spacing: 12) {
                    Button("No") { }.buttonStyle(DarkButtonStyle())
                    Button("Yes") { }.buttonStyle(OrangeButtonStyle())
                }
            }
            .padding(16).background(Color.appCard).cornerRadius(16).padding(.horizontal)
            
            Button { } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up").foregroundColor(.appOrange)
                    Text("Install profile").foregroundColor(.gray).font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundColor(.gray).font(.caption)
                }.padding(16).background(Color.appCard).cornerRadius(16).padding(.horizontal)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                ProgressView().tint(.gray)
                Text("Loading").font(.caption).foregroundColor(.gray)
            }.padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.0)) { progress = 0.8 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                showSplash = false
            }
        }
    }
}
