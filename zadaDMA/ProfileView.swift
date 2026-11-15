import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    var showCloseButton: Bool
    @State private var keyInput = ""
    @State private var showActivation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Profile").font(.title.bold()).foregroundColor(.white).padding(.top)
                
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill").font(.largeTitle).foregroundColor(.gray)
                    Text(state.isActivated ? "Active" : "No membership").font(.headline).foregroundColor(.white)
                    Text("Activate your key to use zadaDMA").font(.caption).foregroundColor(.gray)
                }.padding().frame(maxWidth: .infinity).cardStyle().padding(.horizontal)
                
                Button {
                    showActivation = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill").foregroundColor(.appOrange)
                        Text("Activate key").foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }.padding().cardStyle()
                }.padding(.horizontal)
            }
        }
        .sheet(isPresented: $showActivation) {
            VStack(spacing: 20) {
                Text("Activate membership").font(.title2.bold()).foregroundColor(.white)
                TextField("Your key", text: $keyInput)
                    .padding().background(Color.appCard).cornerRadius(12).foregroundColor(.white)
                Button("Activate key") {
                    if !keyInput.isEmpty {
                        state.isActivated = true
                        state.licenseKey = keyInput
                        showActivation = false
                    }
                }.buttonStyle(OrangeButtonStyle())
                Button("Close") { showActivation = false }.foregroundColor(.appOrange)
            }.padding().presentationDetents([.medium])
        }
    }
}
