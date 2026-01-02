import SwiftUI

// MARK: - Pull Down Actions Overlay
/// A pull-down sheet that reveals quick actions from the top of the screen.
/// More intuitive than a grid at the bottom - feels like a natural gesture.

struct PullDownActionsOverlay: View {
    @Binding var isPresented: Bool
    @Binding var navigateTo: QuickActionDestination?
    @EnvironmentObject var emergencyManager: EmergencyManager
    
    var body: some View {
        // Only render when presented
        if isPresented {
            ZStack {
                // Full screen blur + dark overlay for focus
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }
                
                // Centered quick actions panel
                VStack(spacing: Theme.Spacing.lg) {
                    // Title
                    Text("Quick Actions")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    // Quick actions content
                    QuickActionsContent(
                        onDismiss: {
                            withAnimation(.spring()) {
                                isPresented = false
                            }
                        },
                        onNavigate: { destination in
                            withAnimation(.spring()) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigateTo = destination
                            }
                        }
                    )
                    
                    // Dismiss hint
                    Button(action: {
                        withAnimation(.spring()) {
                            isPresented = false
                        }
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Tap anywhere to close")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                    }
                    .padding(.top, Theme.Spacing.md)
                }
                .padding()
            }
            .zIndex(100)
            .transition(.opacity)
        }
    }
}

// MARK: - Quick Action Destinations
enum QuickActionDestination: Identifiable {
    case messages, tasks, commitments, qrCode, map, guide, events, checkIn, findPerson, addTask, addAnnouncement
    var id: Self { self }
}

// MARK: - Quick Actions Content

struct QuickActionsContent: View {
    let onDismiss: () -> Void
    let onNavigate: (QuickActionDestination) -> Void
    @EnvironmentObject var emergencyManager: EmergencyManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shiftManager: ShiftManager
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Row 1: Safety
            HStack(spacing: Theme.Spacing.md) {
                // SOS - Emergency (critical)
                QuickActionItem(
                    icon: "sos",
                    label: "SOS",
                    color: Theme.Colors.emergency,
                    isDestructive: true
                ) {
                    emergencyManager.sendSOS()
                    onDismiss()
                }
                
                // Check In - Safety
                QuickActionItem(
                    icon: "checkmark.shield.fill",
                    label: "Check In",
                    color: Theme.Colors.connected
                ) {
                    onNavigate(.checkIn)
                }
                
                // Ghost Mode - Privacy toggle
                QuickActionItem(
                    icon: locationManager.isLocationPrivate ? "eye.slash.fill" : "eye.fill",
                    label: locationManager.isLocationPrivate ? "Visible" : "Ghost",
                    color: locationManager.isLocationPrivate ? Theme.Colors.connected : Theme.Colors.backgroundLight
                ) {
                    if locationManager.isLocationPrivate {
                        locationManager.disableGhostMode()
                    } else {
                        locationManager.enableGhostMode()
                    }
                    onDismiss()
                }
            }
            
            // Row 2: Actions
            HStack(spacing: Theme.Spacing.md) {
                // Add Task - quick create
                QuickActionItem(
                    icon: "checklist",
                    label: "Add Task",
                    color: Theme.Colors.turquoise
                ) {
                    onNavigate(.addTask)
                }
                
                // Add Announcement - admin only
                if shiftManager.isAdmin {
                    QuickActionItem(
                        icon: "megaphone.fill",
                        label: "Announce",
                        color: Theme.Colors.goldenYellow
                    ) {
                        onNavigate(.addAnnouncement)
                    }
                }
                
                // Scan QR - Connect with someone
                QuickActionItem(
                    icon: "qrcode.viewfinder",
                    label: "Scan QR",
                    color: Theme.Colors.sunsetOrange
                ) {
                    onNavigate(.qrCode)
                }
            }
        }
    }
}

// MARK: - Quick Action Item (Single Word, Solid Colors)

struct QuickActionItem: View {
    let icon: String
    let label: String
    let color: Color
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.sm) {
                // Icon in solid colored circle
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                // Single word label
                Text(label)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Pull Down Trigger (for navigation bar)

struct PullDownTrigger: View {
    @Binding var showActions: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                showActions.toggle()
            }
        }) {
            Image(systemName: showActions ? "chevron.up" : "chevron.down")
                .font(.title3)
                .foregroundColor(Theme.Colors.sunsetOrange)
                .rotationEffect(.degrees(showActions ? 180 : 0))
        }
    }
}

// Corner radius extension moved to Theme.swift or already exists

// MARK: - Preview

#Preview {
    ZStack {
        Theme.Colors.backgroundDark.ignoresSafeArea()
        
        PullDownActionsOverlay(isPresented: .constant(true), navigateTo: .constant(nil))
            .environmentObject(EmergencyManager())
            .environmentObject(LocationManager())
    }
}
