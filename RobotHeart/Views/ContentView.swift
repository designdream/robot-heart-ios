import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - Dashboard with key info
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "heart.fill")
                }
                .tag(0)
            
            // Shifts - The main work system
            ShiftBlockHubView()
                .tabItem {
                    Label("Shifts", systemImage: "calendar.badge.clock")
                }
                .badge(shiftManager.badgeCount > 0 ? shiftManager.badgeCount : 0)
                .tag(1)
            
            // Camp - Roster, Map, Camp Map
            CampHubView()
                .tabItem {
                    Label("Camp", systemImage: "person.3.fill")
                }
                .tag(2)
            
            // Messages
            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "message.fill")
                }
                .badge(announcementManager.unreadCount > 0 ? announcementManager.unreadCount : 0)
                .tag(3)
            
            // Profile & Settings
            ProfileView()
                .tabItem {
                    Label("Me", systemImage: "person.circle.fill")
                }
                .badge(profileManager.pendingRequestsCount > 0 ? profileManager.pendingRequestsCount : 0)
                .tag(4)
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
        .environmentObject(ShiftManager())
        .environmentObject(EmergencyManager())
        .environmentObject(AnnouncementManager())
        .environmentObject(CheckInManager())
        .environmentObject(EconomyManager())
        .environmentObject(DraftManager())
        .environmentObject(ShiftBlockManager())
        .environmentObject(ProfileManager())
}
