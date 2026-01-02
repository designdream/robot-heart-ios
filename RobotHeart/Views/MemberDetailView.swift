import SwiftUI

struct MemberDetailView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) var dismiss
    
    let member: CampMember
    
    @State private var showingDMComposer = false
    @State private var messageText = ""
    
    var memberShifts: [Shift] {
        shiftManager.shiftsForMember(member.id)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Profile header
                        profileHeader
                        
                        // Quick actions
                        quickActions
                        
                        // Status info
                        statusSection
                        
                        // Shifts
                        if !memberShifts.isEmpty {
                            shiftsSection
                        }
                        
                        // Private Notes
                        MemberNotesView(member: member)
                        
                        // DM Composer
                        if showingDMComposer {
                            dmComposer
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.backgroundLight)
                    .frame(width: 80, height: 80)
                
                Text(member.name.prefix(1))
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            // Name and role
            VStack(spacing: 4) {
                Text(member.name)
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: member.role.icon)
                    Text(member.role.rawValue)
                }
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            // Status badge
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(member.status.rawValue)
                    .font(Theme.Typography.caption)
                Text("• \(member.lastSeenText)")
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    private var quickActions: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Send DM
            QuickActionButton(
                icon: "message.fill",
                title: "Message",
                color: Theme.Colors.turquoise
            ) {
                withAnimation {
                    showingDMComposer.toggle()
                }
            }
            
            // View on map
            QuickActionButton(
                icon: "map.fill",
                title: "Locate",
                color: Theme.Colors.connected,
                disabled: member.location == nil
            ) {
                // TODO: Navigate to map centered on member
            }
            
            // Request shift trade (if they have shifts)
            if !memberShifts.isEmpty {
                QuickActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Trade",
                    color: Theme.Colors.sunsetOrange
                ) {
                    // TODO: Show trade request
                }
            }
        }
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Status")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            VStack(spacing: Theme.Spacing.sm) {
                if let battery = member.batteryLevel {
                    StatusRow(
                        icon: batteryIcon(for: battery),
                        label: "Battery",
                        value: "\(battery)%",
                        color: batteryColor(for: battery)
                    )
                }
                
                if let location = member.location {
                    StatusRow(
                        icon: "location.fill",
                        label: "Location",
                        value: "Updated \(timeAgo(location.timestamp))",
                        color: Theme.Colors.connected
                    )
                }
                
                if let shift = member.currentShift, shift.isActive {
                    StatusRow(
                        icon: "clock.fill",
                        label: "On Shift",
                        value: shift.location.rawValue,
                        color: Theme.Colors.turquoise
                    )
                }
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
    
    private var shiftsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Upcoming Shifts")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            ForEach(memberShifts.filter { $0.isUpcoming }.prefix(3)) { shift in
                HStack {
                    Image(systemName: shift.location.icon)
                        .foregroundColor(Theme.Colors.turquoise)
                    
                    VStack(alignment: .leading) {
                        Text(shift.location.rawValue)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text(formatDateTime(shift.startTime))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Text(shift.durationText)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                .padding()
                .background(Theme.Colors.backgroundMedium)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }
    
    private var dmComposer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Send Message")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            HStack {
                TextField("Message to \(member.name)...", text: $messageText)
                    .foregroundColor(Theme.Colors.robotCream)
                    .padding()
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
                }
                .disabled(messageText.isEmpty)
            }
            
            // Quick message templates
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    QuickMessageChip(text: "Where are you?") { messageText = "Where are you?" }
                    QuickMessageChip(text: "Need help?") { messageText = "Need help?" }
                    QuickMessageChip(text: "Meet at camp") { messageText = "Meet at camp" }
                    QuickMessageChip(text: "On my way") { messageText = "On my way" }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        // Send DM via meshtastic
        meshtasticManager.sendMessage("@\(member.name): \(messageText)", type: .text)
        
        messageText = ""
        showingDMComposer = false
        dismiss()
    }
    
    private var statusColor: Color {
        switch member.status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.disconnected
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 50...100: return Theme.Colors.connected
        case 25..<50: return Theme.Colors.warning
        default: return Theme.Colors.disconnected
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(disabled ? Theme.Colors.robotCream.opacity(0.3) : color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .disabled(disabled)
    }
}

// MARK: - Status Row
struct StatusRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
        }
    }
}

// MARK: - Quick Message Chip
struct QuickMessageChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

#Preview {
    MemberDetailView(member: CampMember.mockMembers[0])
        .environmentObject(MeshtasticManager())
        .environmentObject(ShiftManager())
        .environmentObject(SocialManager())
}
