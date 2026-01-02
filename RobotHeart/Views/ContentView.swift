import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var selectedTab = 0
    
    // MARK: - Badge Logic
    // Badges should only show when ACTION is needed - minimize phone usage
    // "Put down the phone" philosophy - only interrupt for important things
    
    /// Home badge: Urgent announcements only (not all unread)
    var homeBadge: Int {
        announcementManager.announcements.filter { 
            $0.priority == .urgent && !$0.readBy.contains("!local") 
        }.count
    }
    
    /// Community badge: Pending contact requests (someone wants to connect)
    var communityBadge: Int {
        profileManager.pendingRequestsCount
    }
    
    /// My Burn badge: Shifts starting soon (within 1 hour) that need you to leave
    var myBurnBadge: Int {
        let oneHourFromNow = Date().addingTimeInterval(3600)
        return shiftManager.myShifts.filter { 
            $0.startTime > Date() && $0.startTime < oneHourFromNow 
        }.count
    }
    
    /// Messages badge: Urgent help requests only (🆘 messages)
    var messagesBadge: Int {
        meshtasticManager.messages.filter { 
            $0.content.contains("🆘") && $0.timestamp > Date().addingTimeInterval(-3600)
        }.count
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Home - Dashboard with key info, announcements, what's happening
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "heart.fill")
                }
                .badge(homeBadge > 0 ? homeBadge : 0)
                .tag(0)
            
            // Community - THE CORE: People, connections, who's here
            // Research shows human connection is #1 reason people come to Burning Man
            CommunityHubView()
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .badge(communityBadge > 0 ? communityBadge : 0)
                .tag(1)
            
            // My Burn - Your commitments, contributions, opportunities
            ShiftsView()
                .tabItem {
                    Label("My Burn", systemImage: "flame.fill")
                }
                .badge(myBurnBadge > 0 ? myBurnBadge : 0)
                .tag(2)
            
            // Messages - Global Channel + Direct Messages + Announcements
            MessagesHubView()
                .tabItem {
                    Label("Messages", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .badge(messagesBadge > 0 ? messagesBadge : 0)
                .tag(3)
            
            // Me - Profile, QR code, Settings (no badge - no action needed)
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
