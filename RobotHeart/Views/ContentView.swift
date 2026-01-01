import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RosterView()
                .tabItem {
                    Label("Roster", systemImage: "person.3.fill")
                }
                .tag(0)
            
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
                .tag(1)
            
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(Theme.Colors.sunsetOrange)
        .onAppear {
            setupTabBarAppearance()
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.Colors.backgroundMedium)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

#Preview {
    ContentView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
}
