import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var state: AppState
    @State private var step = 1
    @State private var selectedLanguage = "English"
    @State private var selectedAppearance = "System"
    @State private var selectedGame = "Free Fire"
    
    var body: some View {
        VStack {
            // Top Progress Bar
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { i in
                    Capsule().fill(i == step ? Color.appOrange : Color.gray.opacity(0.3))
                        .frame(width: 30, height: 4)
                }
            }.padding(.top, 40)
            
            Spacer()
            
            if step == 1 {
                VStack(spacing: 20) {
                    Text("Choose your language").font(.title2.bold()).foregroundColor(.white)
                    ForEach(["Español", "English", "Português"], id: \.self) { lang in
                        Button {
                            selectedLanguage = lang
                        } label: {
                            HStack {
                                Text(lang).foregroundColor(.white)
                                Spacer()
                                if selectedLanguage == lang { Image(systemName: "checkmark").foregroundColor(.appOrange) }
                            }.padding().cardStyle()
                        }
                    }
                }.padding()
            } else if step == 2 {
                VStack(spacing: 20) {
                    Image(systemName: "xmark").font(.system(size: 60)).foregroundColor(.black).padding(30).background(Color.appOrange).cornerRadius(20)
                    Text("Welcome to X").font(.largeTitle.bold()).foregroundColor(.white)
                    Text("Developed by zadaDMA").foregroundColor(.gray)
                }
            } else if step == 3 {
                VStack(spacing: 20) {
                    Text("Initial setup").font(.title2.bold()).foregroundColor(.white)
                    Text("Appearance").foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        ForEach(["System", "Light", "Dark"], id: \.self) { app in
                            Button(app) { selectedAppearance = app }
                                .foregroundColor(selectedAppearance == app ? .black : .white)
                                .padding(.vertical, 8).frame(maxWidth: .infinity)
                                .background(selectedAppearance == app ? Color.appOrange : Color.appCard)
                                .cornerRadius(8)
                        }
                    }
                    Text("Game").foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                    HStack {
                        ForEach(["Free Fire", "Free Fire MAX"], id: \.self) { game in
                            Button(game) { selectedGame = game }
                                .foregroundColor(selectedGame == game ? .black : .white)
                                .padding().frame(maxWidth: .infinity)
                                .background(selectedGame == game ? Color.appOrange : Color.appCard)
                                .cornerRadius(12)
                        }
                    }
                }.padding()
            } else if step == 4 {
                VStack(spacing: 16) {
                    Text("Supported iOS versions").font(.title2.bold()).foregroundColor(.white)
                    ForEach(["iOS 17", "iOS 18", "iOS 26", "iOS 27"], id: \.self) { ios in
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(ios).foregroundColor(.white)
                            Spacer()
                            Text("Supported").foregroundColor(.gray).font(.caption)
                        }.padding().cardStyle()
                    }
                }.padding()
            } else if step == 5 {
                VStack(spacing: 16) {
                    Text("Certificate requirements").font(.title2.bold()).foregroundColor(.white).multilineTextAlignment(.center)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Works with enterprise certificates").foregroundColor(.white) }
                        HStack { Image(systemName: "xmark.circle.fill").foregroundColor(.red); Text("Does not work with SideStore").foregroundColor(.white) }
                    }.padding().cardStyle()
                }.padding()
            }
            
            Spacer()
            
            HStack {
                if step > 1 {
                    Button("Back") { step -= 1 }
                        .foregroundColor(.white).padding().frame(maxWidth: .infinity).background(Color.appCard).cornerRadius(12)
                }
                Button(step == 5 ? "Finish" : "Next") {
                    if step == 5 { state.hasCompletedOnboarding = true }
                    else { step += 1 }
                }
                .buttonStyle(OrangeButtonStyle())
            }.padding()
        }
    }
}
