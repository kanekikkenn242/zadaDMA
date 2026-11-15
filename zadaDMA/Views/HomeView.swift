import SwiftUI

struct HomeView: View {
    @EnvironmentObject var state: AppState
    @State private var showSettings = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("Home").font(.title.bold()).foregroundColor(.white)
                    Spacer()
                    Image(systemName: "terminal").foregroundColor(.appOrange)
                    Image(systemName: "gearshape").foregroundColor(.appOrange).onTapGesture { showSettings = true }
                }.padding()
                
                HStack {
                    Image(systemName: "xmark").foregroundColor(.black).padding(12).background(Color.appOrange).cornerRadius(12)
                    VStack(alignment: .leading) {
                        Text("zadaDMA").font(.headline).foregroundColor(.white)
                        Text("Your iPhone, ready.").font(.caption).foregroundColor(.gray)
                    }
                    Spacer()
                    Text("Supported").font(.caption).foregroundColor(.green)
                }.padding().cardStyle().padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Device status").font(.headline).foregroundColor(.white)
                    HStack { Text("Hardware model").foregroundColor(.gray); Spacer(); Text(state.deviceModel).foregroundColor(.white) }
                    Divider().background(Color.gray)
                    HStack { Text("iOS Version").foregroundColor(.gray); Spacer(); Text(state.deviceiOS).foregroundColor(.white) }
                    Divider().background(Color.gray)
                    HStack { Text("Exploit compatibility").foregroundColor(.gray); Spacer(); Text("Supported").foregroundColor(.green) }
                }.padding().cardStyle().padding(.horizontal)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
