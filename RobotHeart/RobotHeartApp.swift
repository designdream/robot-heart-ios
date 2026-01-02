import SwiftUI
import UserNotifications
import CoreData

@main
struct RobotHeartApp: App {
    // Core Data persistence
    let persistenceController = PersistenceController.shared
    
    // Existing managers
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
    @StateObject private var campLayoutManager = CampLayoutManager()
    
    // New offline-first managers
    @StateObject private var localDataManager = LocalDataManager.shared
    @StateObject private var bleMeshManager = BLEMeshManager.shared
    @StateObject private var messageQueueManager = MessageQueueManager.shared
    @StateObject private var cloudSyncManager = CloudSyncManager.shared
    @StateObject private var campNetworkManager = CampNetworkManager.shared
    
    // Biometric authentication
    @StateObject private var biometricAuthManager = BiometricAuthManager.shared
    @State private var isUnlocked = false
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        ShiftManager.registerNotificationCategories()
        registerAllNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(profileManager)
                    .environmentObject(biometricAuthManager)
                    .preferredColorScheme(.dark)
            } else if !isUnlocked && biometricAuthManager.isEnabled {
                BiometricLockView(isUnlocked: $isUnlocked)
                    .environmentObject(biometricAuthManager)
                    .preferredColorScheme(.dark)
            } else {
                MainAppView()
                    .environment(\.managedObjectContext, persistenceController.viewContext)
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
                    .environmentObject(campLayoutManager)
                    .environmentObject(localDataManager)
                    .environmentObject(bleMeshManager)
                    .environmentObject(messageQueueManager)
                    .environmentObject(cloudSyncManager)
                    .environmentObject(campNetworkManager)
                    .environmentObject(biometricAuthManager)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        shiftManager.requestNotificationPermissions()
                        startOfflineServices()
                    }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(to: newPhase)
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    private func handleScenePhaseChange(to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            // Lock app when going to background
            if biometricAuthManager.isEnabled {
                isUnlocked = false
            }
        case .active:
            // Check if we need to re-authenticate
            if biometricAuthManager.needsReauthentication {
                isUnlocked = false
            }
        case .inactive:
            break
        @unknown default:
            break
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
    
    private func startOfflineServices() {
        // Start BLE mesh networking
        let userID = UserDefaults.standard.string(forKey: "userID") ?? UUID().uuidString
        let userName = profileManager.myProfile.displayName
        
        // Save user ID if not set
        if UserDefaults.standard.string(forKey: "userID") == nil {
            UserDefaults.standard.set(userID, forKey: "userID")
        }
        UserDefaults.standard.set(userName, forKey: "userName")
        
        // Start BLE advertising and scanning
        bleMeshManager.startAdvertising(userID: userID, userName: userName)
        bleMeshManager.startScanning()
        
        // Start camp network discovery
        campNetworkManager.startDiscovery()
        
        // Setup gateway node relay if online
        if cloudSyncManager.isGatewayNode {
            cloudSyncManager.relayFromCloud()
        }
        
        // Cleanup old data
        localDataManager.cleanupExpiredMessages()
        localDataManager.cleanupOldSyncItems()
    }
}
