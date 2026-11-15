import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 1
    
    var body: some View {
        VStack {
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Capsule().fill(i == step ? Color.appOrange : Color.gray.opacity(0.3)).frame(width: 30, height: 4)
                }
            }.padding(.top, 20)
            
            Spacer()
            
            if step == 1 {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "xmark").font(.title).foregroundColor(.appOrange).padding().background(Color.appCard).cornerRadius(12)
                    Text(state.t("choose_lang")).font(.title.bold()).foregroundColor(.white)
                    Text("You can change this later in Settings.").foregroundColor(.gray).font(.caption)
                    
                    ForEach(["Español", "English", "Português"], id: \.self) { lang in
                        Button {
                            state.language = lang
                        } label: {
                            HStack {
                                Text(lang).foregroundColor(.white)
                                Spacer()
                                if state.language == lang { Image(systemName: "checkmark.circle.fill").foregroundColor(.appOrange) }
                            }
                            .padding().background(Color.appCard).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(state.language == lang ? Color.appOrange : Color.clear, lineWidth: 1))
                        }
                    }
                }.padding(.horizontal)
            } else if step == 2 {
                VStack(spacing: 16) {
                    Image(systemName: "xmark").font(.system(size: 50)).foregroundColor(.black).padding(24).background(Color.appOrange).cornerRadius(20)
                    Text(state.t("welcome")).font(.title.bold()).foregroundColor(.white)
                    Text(state.t("dev")).foregroundColor(.gray)
                    Image(systemName: "checkmark.seal.fill").foregroundColor(.appOrange).padding(.top, 10)
                }
            } else if step == 3 {
                VStack(alignment: .leading, spacing: 20) {
                    Text(state.t("initial")).font(.title.bold()).foregroundColor(.white)
                    
                    Text(state.t("appearance")).foregroundColor(.gray).font(.caption)
                    HStack(spacing: 0) {
                        ForEach(["System", "Light", "Dark"], id: \.self) { app in
                            Button(state.t(app.lowercased())) { state.appearance = app }
                                .foregroundColor(state.appearance == app ? .black : .white)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(state.appearance == app ? Color.appOrange : Color.appCard)
                        }
                    }.cornerRadius(10)
                    
                    Text(state.t("game")).foregroundColor(.gray).font(.caption).padding(.top, 10)
                    HStack(spacing: 12) {
                        ForEach(["Free Fire", "Free Fire MAX"], id: \.self) { game in
                            Button(game) { state.selectedGame = game }
                                .foregroundColor(state.selectedGame == game ? .black : .white)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(state.selectedGame == game ? Color.appOrange : Color.appCard)
                                .cornerRadius(12)
                        }
                    }
                }.padding(.horizontal)
            } else if step == 4 {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Supported iOS versions").font(.title2.bold()).foregroundColor(.white)
                    Text("X allows only the exact build IDs listed in Settings.").foregroundColor(.gray).font(.caption)
                    
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(ios).foregroundColor(.white).font(.headline)
                            Spacer()
                            Text("Supported").foregroundColor(.gray).font(.caption)
                        }.padding().background(Color.appCard).cornerRadius(12)
                    }
                    
                    Text("This device: \(state.deviceiOS)").foregroundColor(.gray).font(.caption).frame(maxWidth: .infinity, alignment: .center).padding(.top)
                }.padding(.horizontal)
            } else if step == 5 {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.shield.fill").font(.largeTitle).foregroundColor(.appOrange)
                    Text(state.t("cert_req")).font(.title2.bold()).foregroundColor(.white)
                    Text("X requires a supported signing method to access device features.").foregroundColor(.gray).font(.caption).multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Works with enterprise certificates").foregroundColor(.white).font(.caption) }
                        HStack { Image(systemName: "xmark.circle.fill").foregroundColor(.red); Text("Does not work with SideStore, AltStore").foregroundColor(.white).font(.caption) }
                    }.padding().background(Color.appCard).cornerRadius(16)
                }.padding(.horizontal)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if step > 1 {
                    Button(state.t("back")) { step -= 1 }.buttonStyle(DarkButtonStyle())
                }
                Button(step == 5 ? state.t("finish") : state.t("next")) {
                    if step == 5 { state.hasCompletedOnboarding = true }
                    else { step += 1 }
                }.buttonStyle(OrangeButtonStyle())
            }.padding(.horizontal).padding(.bottom, 20)
        }
    }
}
