import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var emergencyManager: EmergencyManager
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var showingShareSheet = false
    
    var membersWithLocation: [CampMember] {
        meshtasticManager.campMembers.filter { $0.location != nil }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Map
                    Map(coordinateRegion: $region, annotationItems: membersWithLocation) { member in
                        MapAnnotation(coordinate: member.location!.coordinate) {
                            MemberMapMarker(member: member)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(Theme.CornerRadius.md)
                    .padding()
                    
                    // Location sharing controls
                    locationControlsView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Location")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
    
    private var locationControlsView: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Sharing status
            if locationManager.isSharing {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(Theme.Colors.connected)
                    Text("Sharing location every \(Int(locationManager.shareInterval / 60)) minutes")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                .padding()
                .background(Theme.Colors.backgroundMedium)
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                // Share location once
                ActionButton(
                    title: "Share Now",
                    icon: "location.fill",
                    color: Theme.Colors.turquoise,
                    action: {
                        locationManager.shareCurrentLocation()
                    }
                )
                
                // Toggle auto-sharing
                ActionButton(
                    title: locationManager.isSharing ? "Stop Sharing" : "Auto Share",
                    icon: locationManager.isSharing ? "pause.fill" : "play.fill",
                    color: locationManager.isSharing ? Theme.Colors.disconnected : Theme.Colors.connected,
                    action: {
                        if locationManager.isSharing {
                            locationManager.stopSharing()
                        } else {
                            locationManager.startSharing()
                        }
                    }
                )
            }
            
            // SOS Button
            SOSButtonView()
        }
        .padding()
        .background(Theme.Colors.backgroundDark)
    }
}

// MARK: - Member Map Marker
struct MemberMapMarker: View {
    let member: CampMember
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulse effect for online members
            if member.isOnline {
                Circle()
                    .fill(Theme.Colors.sunsetOrange.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(Theme.Animations.pulse, value: isPulsing)
            }
            
            // Marker
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(statusColor(for: member.status))
                        .frame(width: 30, height: 30)
                    
                    Text(member.name.prefix(1))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Shift indicator
                if member.currentShift?.isActive == true {
                    Image(systemName: member.role.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Theme.Colors.turquoise)
                        .clipShape(Circle())
                        .offset(y: -5)
                }
            }
        }
        .onAppear {
            if member.isOnline {
                isPulsing = true
            }
        }
    }
    
    private func statusColor(for status: CampMember.ConnectionStatus) -> Color {
        switch status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.disconnected
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

#Preview {
    MapView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
        .environmentObject(EmergencyManager())
}
