import SwiftUI

struct ContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var channelManager: ChannelManager
    @State private var selectedTab = 0
    
    // Navigation reset triggers - changing these UUIDs forces views to reset to root
    @State private var homeNavID = UUID()
    @State private var communityNavID = UUID()
    @State private var myBurnNavID = UUID()
    @State private var meNavID = UUID()
    
    // Deep link to DM with specific member
    @State private var dmMemberID: String?
    
    // MARK: - Badge Logic
    // Badges should only show when ACTION is needed - minimize phone usage
    // "Put down the phone" philosophy - only interrupt for important things
    
    /// Home badge: Urgent announcements only (not all unread)
    var homeBadge: Int {
        announcementManager.announcements.filter { 
            $0.priority == .urgent && !$0.readBy.contains("!local") 
        }.count
    }
    
    /// Community badge: Pending contact requests + unread channel messages
    var communityBadge: Int {
        profileManager.pendingRequestsCount + channelManager.totalUnreadCount
    }
    
    /// My Burn badge: Shifts starting soon (within 1 hour) that need you to leave
    var myBurnBadge: Int {
        let oneHourFromNow = Date().addingTimeInterval(3600)
        return shiftManager.myShifts.filter { 
            $0.startTime > Date() && $0.startTime < oneHourFromNow 
        }.count
    }
    
    var body: some View {
        TabView(selection: tabSelection) {
            // Home - Dashboard with key info, announcements, what's happening
            HomeView()
                .id(homeNavID)
                .tabItem {
                    Label("Home", systemImage: "heart.fill")
                }
                .badge(homeBadge > 0 ? homeBadge : 0)
                .tag(0)
            
            // Community - THE CORE: People, Channels, DMs
            // Unified communication hub - no separate Messages tab
            CommunityHubView()
                .id(communityNavID)
                .tabItem {
                    Label("Community", systemImage: "person.3.fill")
                }
                .badge(communityBadge > 0 ? communityBadge : 0)
                .tag(1)
            
            // My Burn - Your commitments, tasks, contributions
            ShiftsView()
                .id(myBurnNavID)
                .tabItem {
                    Label("My Burn", systemImage: "flame.fill")
                }
                .badge(myBurnBadge > 0 ? myBurnBadge : 0)
                .tag(2)
            
            // Me - Profile, QR code, Settings (no badge - no action needed)
            ProfileView()
                .id(meNavID)
                .tabItem {
                    Label("Me", systemImage: "person.circle.fill")
                }
                .tag(3)
        }
        .accentColor(Theme.Colors.sunsetOrange)
        .onAppear {
            setupTabBarAppearance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openDirectMessage)) { notification in
            if let memberID = notification.object as? String {
                openDMWithMember(memberID)
            }
        }
    }
    
    // MARK: - Tab Selection with Double-Tap to Pop to Root
    /// Binding that detects when user taps the already-selected tab (double-tap)
    /// and resets that tab's navigation to root
    var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == selectedTab {
                    // Double-tap detected - reset navigation for this tab
                    resetNavigationForTab(newTab)
                }
                selectedTab = newTab
            }
        )
    }
    
    /// Reset navigation to root for the specified tab
    private func resetNavigationForTab(_ tab: Int) {
        switch tab {
        case 0: homeNavID = UUID()
        case 1: communityNavID = UUID()
        case 2: myBurnNavID = UUID()
        case 3: meNavID = UUID()
        default: break
        }
    }
    
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.Colors.backgroundMedium)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    /// Navigate to Community tab (DMs section) with specific member
    func openDMWithMember(_ memberID: String) {
        dmMemberID = memberID
        selectedTab = 1 // Community tab (now has DMs)
        communityNavID = UUID()
    }
}

// MARK: - Notification for opening DM
extension Notification.Name {
    static let openDirectMessage = Notification.Name("openDirectMessage")
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
        .environmentObject(ChannelManager())
}
