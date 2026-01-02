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
            // Home - Dashboard with key info, announcements, what's happening
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "heart.fill")
                }
                .tag(0)
            
            // Community - THE CORE: People, connections, who's here
            // Research shows human connection is #1 reason people come to Burning Man
            CommunityHubView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .badge(profileManager.pendingRequestsCount > 0 ? profileManager.pendingRequestsCount : 0)
                .tag(1)
            
            // My Burn - Your commitments, contributions, opportunities
            ShiftsView()
                .tabItem {
                    Label("My Burn", systemImage: "flame.fill")
                }
                .badge(shiftManager.badgeCount > 0 ? shiftManager.badgeCount : 0)
                .tag(2)
            
            // Messages - Global Channel + Direct Messages + Announcements
            MessagesHubView()
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(announcementManager.unreadCount > 0 ? announcementManager.unreadCount : 0)
                .tag(3)
            
            // Me - Profile, QR code, Settings
            ProfileView()
                .tabItem {
                    Label("Me", systemImage: "person.circle.fill")
                }
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
