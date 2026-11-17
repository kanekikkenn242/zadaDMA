import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var state: AppState
    @State private var showActivation = false
    @State private var keyInput = ""
    @State private var errorMsg = ""
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(state.t("profile")).font(.title.bold()).foregroundColor(.white).padding(.top, 20)
                
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill").font(.largeTitle).foregroundColor(.gray)
                    Text(state.isActivated ? "Premium Active" : state.t("no_membership")).font(.headline).foregroundColor(.white)
                    Text("Activate your key to use zadaDMA").font(.caption).foregroundColor(.gray)
                }.frame(maxWidth: .infinity).cardStyle().padding(.horizontal)
                .overlay(Rectangle().frame(width: 4).foregroundColor(.appOrange), alignment: .leading).padding(.horizontal)
                
                Button {
                    showActivation = true
                } label: {
                    HStack {
                        Image(systemName: "key.fill").foregroundColor(.appOrange).padding(10).background(Color.black).cornerRadius(10)
                        VStack(alignment: .leading) {
                            Text(state.t("activate_key")).foregroundColor(.white).font(.headline)
                            Text(state.t("enter_key")).foregroundColor(.gray).font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }.cardStyle()
                }.padding(.horizontal)

                Button {
                    showSettings = true
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill").foregroundColor(.appOrange).padding(10).background(Color.black).cornerRadius(10)
                        VStack(alignment: .leading) {
                            Text("Ajustes").foregroundColor(.white).font(.headline)
                            Text("Sistema, dispositivo y versiones").foregroundColor(.gray).font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundColor(.gray)
                    }.cardStyle()
                }.padding(.horizontal)
            }
        }
        .sheet(isPresented: $showActivation) {
            VStack(spacing: 20) {
                Text("Activate membership").font(.title2.bold()).foregroundColor(.white)
                TextField(state.t("your_key"), text: $keyInput).padding().background(Color.appCard).cornerRadius(12).foregroundColor(.white).autocorrectionDisabled().textInputAutocapitalization(.never)
                if !errorMsg.isEmpty { Text(errorMsg).foregroundColor(.red).font(.caption) }
                
                Button(state.t("activate")) {
                    if keyInput == "ZADADMA2026" {
                        state.isActivated = true
                        showActivation = false
                    } else {
                        errorMsg = "Invalid key"
                    }
                }.buttonStyle(OrangeButtonStyle())
                
                Button(state.t("close")) { showActivation = false }.foregroundColor(.gray)
                Spacer()
            }.padding().presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(state)
        }
    }
}
