import SwiftUI
import UserNotifications

@main
struct RobotHeartApp: App {
    @StateObject private var meshtasticManager = MeshtasticManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var shiftManager = ShiftManager()
    @StateObject private var emergencyManager = EmergencyManager()
    @StateObject private var announcementManager = AnnouncementManager()
    @StateObject private var checkInManager = CheckInManager()
    @StateObject private var economyManager = EconomyManager()
    @StateObject private var draftManager = DraftManager()
    @StateObject private var shiftBlockManager = ShiftBlockManager()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var socialManager = SocialManager()
    @StateObject private var taskManager = TaskManager()
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        ShiftManager.registerNotificationCategories()
        registerAllNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainAppView()
                    .environmentObject(meshtasticManager)
                    .environmentObject(locationManager)
                    .environmentObject(shiftManager)
                    .environmentObject(emergencyManager)
                    .environmentObject(announcementManager)
                    .environmentObject(checkInManager)
                    .environmentObject(economyManager)
                    .environmentObject(draftManager)
                    .environmentObject(shiftBlockManager)
                    .environmentObject(profileManager)
                    .environmentObject(socialManager)
                    .environmentObject(taskManager)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        shiftManager.requestNotificationPermissions()
                    }
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(profileManager)
                    .preferredColorScheme(.dark)
            }
        }
    }
    
    private func registerAllNotificationCategories() {
        // Emergency category
        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE_EMERGENCY",
            title: "Acknowledge",
            options: [.foreground]
        )
        
        let emergencyCategory = UNNotificationCategory(
            identifier: "EMERGENCY",
            actions: [acknowledgeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Check-in category
        let checkInAction = UNNotificationAction(
            identifier: "CHECK_IN",
            title: "I'm OK",
            options: []
        )
        
        let checkInCategory = UNNotificationCategory(
            identifier: "CHECKIN",
            actions: [checkInAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Announcement category
        let viewAction = UNNotificationAction(
            identifier: "VIEW_ANNOUNCEMENT",
            title: "View",
            options: [.foreground]
        )
        
        let announcementCategory = UNNotificationCategory(
            identifier: "ANNOUNCEMENT",
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            emergencyCategory,
            checkInCategory,
            announcementCategory
        ])
    }
}
