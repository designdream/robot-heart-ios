import SwiftUI

// MARK: - Check-In Card (for home/roster view)
struct CheckInCard: View {
    @EnvironmentObject var checkInManager: CheckInManager
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Check-In")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Last: \(checkInManager.checkInStatusText)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(statusColor)
                }
                
                Spacer()
                
                // Check-in button
                Button(action: {
                    checkInManager.checkIn()
                    showingConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("I'm OK")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(checkInManager.isCheckInOverdue ? Theme.Colors.emergency : Theme.Colors.connected)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
            
            // Progress bar to next check-in
            if let nextDue = checkInManager.nextCheckInDue {
                CheckInProgressBar(
                    lastCheckIn: checkInManager.lastCheckIn ?? Date(),
                    nextDue: nextDue,
                    isOverdue: checkInManager.isCheckInOverdue
                )
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(checkInManager.isCheckInOverdue ? Theme.Colors.emergency : Color.clear, lineWidth: 2)
        )
        .alert("Checked In!", isPresented: $showingConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your camp knows you're safe.")
        }
    }
    
    private var statusColor: Color {
        if checkInManager.isCheckInOverdue {
            return Theme.Colors.emergency
        } else if checkInManager.timeSinceLastCheckIn > checkInManager.checkInInterval * 0.75 {
            return Theme.Colors.warning
        }
        return Theme.Colors.connected
    }
}

// MARK: - Check-In Progress Bar
struct CheckInProgressBar: View {
    let lastCheckIn: Date
    let nextDue: Date
    let isOverdue: Bool
    
    private var progress: Double {
        let total = nextDue.timeIntervalSince(lastCheckIn)
        let elapsed = Date().timeIntervalSince(lastCheckIn)
        return min(1.0, max(0, elapsed / total))
    }
    
    private var timeRemainingText: String {
        let remaining = nextDue.timeIntervalSinceNow
        if remaining <= 0 {
            return "Overdue"
        } else if remaining < 3600 {
            return "\(Int(remaining / 60))m until next check-in"
        } else {
            return "\(Int(remaining / 3600))h until next check-in"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.backgroundLight)
                        .frame(height: 4)
                        .cornerRadius(2)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
            
            Text(timeRemainingText)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
    }
    
    private var progressColor: Color {
        if isOverdue {
            return Theme.Colors.emergency
        } else if progress > 0.75 {
            return Theme.Colors.warning
        }
        return Theme.Colors.connected
    }
}

// MARK: - Check-In Settings View
struct CheckInSettingsView: View {
    @EnvironmentObject var checkInManager: CheckInManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Check-In Interval")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(CheckInManager.IntervalOption.allCases, id: \.self) { option in
                    IntervalButton(
                        title: option.title,
                        isSelected: checkInManager.checkInInterval == option.interval,
                        action: {
                            checkInManager.setCheckInInterval(option.interval)
                        }
                    )
                }
            }
            
            Text("You'll be reminded to check in before this time expires")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
    }
}

struct IntervalButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isSelected ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Overdue Members Alert
struct OverdueMembersView: View {
    @EnvironmentObject var checkInManager: CheckInManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    
    var overdueMembers: [CampMember] {
        meshtasticManager.campMembers.filter { member in
            checkInManager.overdueMembers.contains(member.id)
        }
    }
    
    var body: some View {
        if !overdueMembers.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.warning)
                    
                    Text("Members haven't checked in")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ForEach(overdueMembers) { member in
                    HStack {
                        Text(member.name)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Spacer()
                        
                        if let lastCheckIn = checkInManager.memberCheckIns[member.id] {
                            Text(timeAgo(lastCheckIn))
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.warning)
                        }
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.Colors.warning, lineWidth: 1)
            )
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
}

#Preview {
    VStack {
        CheckInCard()
        CheckInSettingsView()
    }
    .padding()
    .background(Theme.Colors.backgroundDark)
    .environmentObject(CheckInManager())
}
