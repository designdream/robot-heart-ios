import SwiftUI

struct ShiftsView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var showingAdminView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Active shift card
                        if let activeShift = shiftManager.activeShifts.first {
                            ActiveShiftCard(shift: activeShift)
                        }
                        
                        // Next shift card
                        if let nextShift = shiftManager.nextShift {
                            NextShiftCard(shift: nextShift) {
                                shiftManager.acknowledgeShift(nextShift)
                            }
                        }
                        
                        // No shifts placeholder
                        if shiftManager.myShifts.isEmpty {
                            NoShiftsView()
                        } else {
                            // Upcoming shifts
                            if !shiftManager.upcomingShifts.isEmpty {
                                ShiftSection(
                                    title: "Upcoming Shifts",
                                    shifts: Array(shiftManager.upcomingShifts.dropFirst()),
                                    emptyMessage: nil
                                )
                            }
                            
                            // Past shifts
                            if !shiftManager.pastShifts.isEmpty {
                                ShiftSection(
                                    title: "Past Shifts",
                                    shifts: Array(shiftManager.pastShifts.prefix(5)),
                                    emptyMessage: nil,
                                    isCollapsible: true
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Shifts")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if shiftManager.isAdmin {
                        Button(action: { showingAdminView = true }) {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdminView) {
                ShiftAdminView()
                    .environmentObject(shiftManager)
                    .environmentObject(meshtasticManager)
            }
        }
    }
}

// MARK: - Active Shift Card
struct ActiveShiftCard: View {
    let shift: Shift
    @State private var timeRemaining: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: shift.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.backgroundDark)
                
                Text("ON SHIFT NOW")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.backgroundDark)
                
                Spacer()
                
                Text(timeRemainingText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.backgroundDark.opacity(0.8))
            }
            
            Text(shift.location.rawValue)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.backgroundDark)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let notes = shift.notes {
                Text(notes)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.backgroundDark.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            HStack {
                Label(formatTime(shift.startTime), systemImage: "clock")
                Text("→")
                Label(formatTime(shift.endTime), systemImage: "clock.badge.checkmark")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.backgroundDark.opacity(0.7))
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.connected)
        .cornerRadius(Theme.CornerRadius.lg)
        .onReceive(timer) { _ in
            timeRemaining = shift.endTime.timeIntervalSinceNow
        }
        .onAppear {
            timeRemaining = shift.endTime.timeIntervalSinceNow
        }
    }
    
    private var timeRemainingText: String {
        if timeRemaining <= 0 {
            return "Ending..."
        }
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Next Shift Card
struct NextShiftCard: View {
    let shift: Shift
    let onAcknowledge: () -> Void
    @State private var timeUntil: TimeInterval = 0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NEXT SHIFT")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    
                    Text(countdownText)
                        .font(Theme.Typography.title)
                        .foregroundColor(urgencyColor)
                }
                
                Spacer()
                
                Image(systemName: shift.location.icon)
                    .font(.system(size: 40))
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            Divider()
                .background(Theme.Colors.robotCream.opacity(0.3))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("\(formatTime(shift.startTime)) - \(formatTime(shift.endTime))")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    
                    if let notes = shift.notes {
                        Text(notes)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            .padding(.top, 2)
                    }
                }
                
                Spacer()
            }
            
            if !shift.acknowledged {
                Button(action: onAcknowledge) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Acknowledge")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(urgencyColor.opacity(0.5), lineWidth: isUrgent ? 2 : 0)
        )
        .onReceive(timer) { _ in
            timeUntil = shift.timeUntilStart
        }
        .onAppear {
            timeUntil = shift.timeUntilStart
        }
    }
    
    private var isUrgent: Bool {
        timeUntil < 3600 // Less than 1 hour
    }
    
    private var urgencyColor: Color {
        if timeUntil < 900 { // Less than 15 min
            return Theme.Colors.emergency
        } else if timeUntil < 3600 { // Less than 1 hour
            return Theme.Colors.sunsetOrange
        }
        return Theme.Colors.robotCream
    }
    
    private var countdownText: String {
        if timeUntil <= 0 {
            return "Starting now!"
        }
        
        let days = Int(timeUntil) / 86400
        let hours = (Int(timeUntil) % 86400) / 3600
        let minutes = (Int(timeUntil) % 3600) / 60
        let seconds = Int(timeUntil) % 60
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Shift Section
struct ShiftSection: View {
    let title: String
    let shifts: [Shift]
    let emptyMessage: String?
    var isCollapsible: Bool = false
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button(action: {
                if isCollapsible {
                    withAnimation { isExpanded.toggle() }
                }
            }) {
                HStack {
                    Text(title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    
                    if isCollapsible {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Spacer()
                }
            }
            .disabled(!isCollapsible)
            
            if isExpanded {
                if shifts.isEmpty {
                    if let message = emptyMessage {
                        Text(message)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            .padding(.vertical, Theme.Spacing.md)
                    }
                } else {
                    ForEach(shifts) { shift in
                        ShiftRow(shift: shift)
                    }
                }
            }
        }
    }
}

// MARK: - Shift Row
struct ShiftRow: View {
    let shift: Shift
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: shift.location.icon)
                .font(.title3)
                .foregroundColor(Theme.Colors.turquoise)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - No Shifts View
struct NoShiftsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Shifts Assigned")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Your shift schedule will appear here once an admin assigns you shifts.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    ShiftsView()
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
}
