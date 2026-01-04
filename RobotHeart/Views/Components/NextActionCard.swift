import SwiftUI

/// Personalized "Next Action" card that suggests what the user should do next
/// Based on connection status, time of day, and user context
struct NextActionCard: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    
    var body: some View {
        if let action = suggestedAction {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: action.icon)
                        .font(.title2)
                        .foregroundColor(Color(hex: Theme.Colors.sunsetOrange))
                    
                    Text("Next Action")
                        .font(.headline)
                        .foregroundColor(Color(hex: Theme.Colors.robotCream))
                    
                    Spacer()
                    
                    if action.isUrgent {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(Color(hex: Theme.Colors.sunsetOrange))
                    }
                }
                
                // Title
                Text(action.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: Theme.Colors.robotCream))
                
                // Description
                Text(action.description)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action button
                Button(action: action.action) {
                    HStack {
                        Text(action.buttonText)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(Color(hex: Theme.Colors.blackPlaya))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: Theme.Colors.sunsetOrange))
                    .cornerRadius(12)
                }
            }
            .padding()
            .background(Color(hex: Theme.Colors.deepNight))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(hex: Theme.Colors.sunsetOrange).opacity(action.isUrgent ? 0.5 : 0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Suggested Action Logic
    
    private var suggestedAction: NextAction? {
        // Priority 1: Not connected to mesh network
        if !appEnvironment.meshtasticLegacy.isConnected {
            return NextAction(
                icon: "antenna.radiowaves.left.and.right.slash",
                title: "Connect to Mesh Network",
                description: "You're not connected to the mesh network. Connect to communicate with your camp.",
                buttonText: "Connect Now",
                isUrgent: true,
                action: { /* Navigate to connection view */ }
            )
        }
        
        // Priority 2: Location sharing disabled
        if !appEnvironment.location.isLocationSharingEnabled {
            return NextAction(
                icon: "location.slash",
                title: "Enable Location Sharing",
                description: "Your camp mates can't see where you are. Turn on location sharing to stay connected.",
                buttonText: "Enable Location",
                isUrgent: false,
                action: { appEnvironment.location.requestLocationPermission() }
            )
        }
        
        // Priority 3: No camp members (first time user)
        if appEnvironment.meshtasticLegacy.campMembers.isEmpty {
            return NextAction(
                icon: "qrcode.viewfinder",
                title: "Add Your First Camp Mate",
                description: "Scan a QR code to add camp members and start communicating.",
                buttonText: "Scan QR Code",
                isUrgent: false,
                action: { /* Navigate to QR scanner */ }
            )
        }
        
        // Priority 4: Cloud sync not configured
        if !appEnvironment.cloudSync.hasCredentials {
            return NextAction(
                icon: "cloud.slash",
                title: "Enable Cloud Sync",
                description: "Configure cloud sync to keep your messages backed up when you have WiFi or Starlink.",
                buttonText: "Configure S3",
                isUrgent: false,
                action: { /* Navigate to S3 settings */ }
            )
        }
        
        // Priority 5: Time-based suggestions
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 6 && hour < 12 {
            // Morning: Check in with camp
            return NextAction(
                icon: "sun.max",
                title: "Good Morning!",
                description: "Check in with your camp and see who's around today.",
                buttonText: "View Roster",
                isUrgent: false,
                action: { /* Navigate to roster */ }
            )
        } else if hour >= 12 && hour < 17 {
            // Afternoon: Explore
            return NextAction(
                icon: "map",
                title: "Explore the Playa",
                description: "See where your camp mates are and discover what's happening nearby.",
                buttonText: "Open Map",
                isUrgent: false,
                action: { /* Navigate to map */ }
            )
        } else if hour >= 17 && hour < 22 {
            // Evening: Social
            return NextAction(
                icon: "message",
                title: "Connect with Your Camp",
                description: "Send a message to coordinate sunset plans or check in on friends.",
                buttonText: "Send Message",
                isUrgent: false,
                action: { /* Navigate to messages */ }
            )
        } else {
            // Night: Safety
            return NextAction(
                icon: "moon.stars",
                title: "Stay Safe Out There",
                description: "Make sure your location is shared so your camp knows you're okay.",
                buttonText: "Check Settings",
                isUrgent: false,
                action: { /* Navigate to settings */ }
            )
        }
    }
}

// MARK: - Data Model

struct NextAction {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let isUrgent: Bool
    let action: () -> Void
}

// MARK: - Preview

#Preview {
    NextActionCard()
        .environmentObject(AppEnvironment())
        .padding()
        .background(Color(hex: Theme.Colors.blackPlaya))
}
