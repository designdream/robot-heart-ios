import SwiftUI
import UserNotifications
import CoreData

@main
struct RobotHeartApp: App {
    // Centralized app environment (replaces 20+ individual managers)
    @StateObject private var environment = AppEnvironment()
    
    // Biometric lock state
    @State private var isUnlocked = false
    
    // Onboarding state
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        ShiftManager.registerNotificationCategories()
        registerAllNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .withAppEnvironment(environment)
                    .preferredColorScheme(.dark)
            } else if !isUnlocked && environment.biometricAuth.isEnabled {
                BiometricLockView(isUnlocked: $isUnlocked)
                    .environmentObject(environment.biometricAuth)
                    .preferredColorScheme(.dark)
            } else {
                MainAppView()
                    .withAppEnvironment(environment)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        environment.startServices()
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
            if environment.biometricAuth.isEnabled {
                isUnlocked = false
            }
            // Stop services to save battery
            environment.stopServices()
            
        case .active:
            // Check if we need to re-authenticate
            if environment.biometricAuth.needsReauthentication {
                isUnlocked = false
            }
            // Resume services
            if hasCompletedOnboarding && isUnlocked {
                environment.resumeServices()
            }
            
        case .inactive:
            // Pause services
            environment.pauseServices()
            
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
}
