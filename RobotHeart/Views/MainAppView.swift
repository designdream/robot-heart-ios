import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var emergencyManager: EmergencyManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var checkInManager: CheckInManager
    
    var body: some View {
        ZStack {
            // Main content
            ContentView()
            
            // Announcement banner at top
            VStack {
                if let announcement = announcementManager.latestAnnouncement {
                    AnnouncementBanner(
                        announcement: announcement,
                        onDismiss: {
                            announcementManager.dismissLatest()
                        },
                        onTap: {
                            announcementManager.markAsRead(announcement)
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
            }
            .animation(.spring(), value: announcementManager.latestAnnouncement != nil)
            
            // Emergency overlay (highest priority)
            if let emergency = emergencyManager.activeEmergency {
                EmergencyAlertOverlay(emergency: emergency)
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .animation(.easeInOut, value: emergencyManager.activeEmergency != nil)
    }
}

#Preview {
    MainAppView()
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
