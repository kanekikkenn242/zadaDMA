import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(state.t("home")).font(.title.bold()).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "terminal").foregroundColor(.appOrange).font(.title2)
                    Image(systemName: "gearshape").foregroundColor(.appOrange).font(.title2).onTapGesture { showSettings = true }
                }.padding(.horizontal)
                
                HStack {
                    Image(systemName: "xmark").foregroundColor(.black).padding(12).background(Color.appOrange).cornerRadius(12)
                    VStack(alignment: .leading) {
                        Text("zadaDMA").font(.headline).foregroundColor(.white)
                        Text("Your iPhone, ready.").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Text(state.t("supported")).font(.caption).foregroundColor(.green).padding(6).background(Color.green.opacity(0.1)).cornerRadius(8)
                }.cardStyle().padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text(state.t("device_status")).font(.headline).foregroundColor(.white)
                    HStack { Text(state.t("hardware")).foregroundColor(.gray); Spacer(); Text(state.deviceModel).foregroundColor(.white) }
                    Divider().background(Color.gray.opacity(0.3))
                    HStack { Text(state.t("ios")).foregroundColor(.gray); Spacer(); Text(state.deviceiOS).foregroundColor(.white) }
                    Divider().background(Color.gray.opacity(0.3))
                    HStack { Text(state.t("exploit")).foregroundColor(.gray); Spacer(); Text(state.t("supported")).foregroundColor(.green) }
                }.cardStyle().padding(.horizontal)
            }.padding(.top, 20)
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}
