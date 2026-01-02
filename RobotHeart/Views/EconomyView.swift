import SwiftUI

// MARK: - Economy Dashboard View
struct EconomyDashboardView: View {
    @EnvironmentObject var economyManager: EconomyManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Standing card
                    StandingCard(standing: economyManager.myStanding)
                    
                    // Active penalties banner
                    if !economyManager.activePenalties.isEmpty {
                        PenaltyBanner(penalties: economyManager.activePenalties)
                    }
                    
                    // Tab selector
                    Picker("View", selection: $selectedTab) {
                        Text("Available").tag(0)
                        Text("My Shifts").tag(1)
                        Text("Standings").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        AvailableShiftsView()
                            .tag(0)
                        
                        MyClaimsView()
                            .tag(1)
                        
                        LeaderboardView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Shift Economy")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                economyManager.refreshAvailableShifts()
                economyManager.refreshLeaderboard()
            }
        }
    }
}

// MARK: - Standing Card
struct StandingCard: View {
    let standing: ParticipantStanding
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Points")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(standing.pointsEarned)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        
                        Text("/ \(standing.pointsRequired)")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Reliability badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Reliability")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    
                    Text("\(Int(standing.reliabilityScore * 100))%")
                        .font(Theme.Typography.title2)
                        .foregroundColor(reliabilityColor)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.backgroundLight)
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(progressColor)
                        .frame(width: geometry.size.width * standing.completionPercentage, height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            // Stats row
            HStack {
                StatPill(icon: "checkmark.circle", value: "\(standing.shiftsCompleted)", label: "Completed")
                Spacer()
                StatPill(icon: "xmark.circle", value: "\(standing.shiftsNoShow)", label: "No-shows", isNegative: standing.shiftsNoShow > 0)
                Spacer()
                StatPill(icon: "star.fill", value: standing.currentTier.name, label: "Tier")
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .padding()
    }
    
    private var reliabilityColor: Color {
        if standing.reliabilityScore >= 0.95 { return Theme.Colors.connected }
        if standing.reliabilityScore >= 0.8 { return Theme.Colors.warning }
        return Theme.Colors.emergency
    }
    
    private var progressColor: Color {
        if standing.completionPercentage >= 1.0 { return Theme.Colors.connected }
        if standing.completionPercentage >= 0.5 { return Theme.Colors.sunsetOrange }
        return Theme.Colors.warning
    }
}

// MARK: - Stat Pill
struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    var isNegative: Bool = false
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(value)
                    .font(Theme.Typography.headline)
            }
            .foregroundColor(isNegative ? Theme.Colors.emergency : Theme.Colors.robotCream)
            
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
    }
}

// MARK: - Penalty Banner
struct PenaltyBanner: View {
    let penalties: [Penalty]
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(penalties) { penalty in
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.emergency)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(penalty.reason.rawValue)
                            .font(Theme.Typography.headline)
                            .foregroundColor(.white)
                        
                        Text("Privileges suspended for \(formatDuration(penalty.remainingTime))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Theme.Colors.emergency.opacity(0.9))
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(.horizontal)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Available Shifts View (Anonymous)
struct AvailableShiftsView: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                if economyManager.availableShifts.isEmpty {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "No Shifts Available",
                        message: "Check back soon for new opportunities"
                    )
                } else {
                    ForEach(economyManager.availableShifts) { shift in
                        AnonymousShiftCard(shift: shift)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Anonymous Shift Card
struct AnonymousShiftCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    let shift: AnonymousShift
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                // Location & time (no names shown)
                Image(systemName: shift.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.turquoise)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(formatTime(shift.startTime))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                // Points badge
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        if shift.isUrgent {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(Theme.Colors.warning)
                        }
                        Text("+\(shift.totalPoints)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                    
                    Text("points")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            // Duration & spots
            HStack {
                Label("\(String(format: "%.1f", shift.durationHours))h", systemImage: "clock")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                
                Spacer()
                
                Text("\(shift.spotsRemaining) spot\(shift.spotsRemaining == 1 ? "" : "s") left")
                    .font(Theme.Typography.caption)
                    .foregroundColor(shift.spotsRemaining == 1 ? Theme.Colors.warning : Theme.Colors.robotCream.opacity(0.6))
            }
            
            // Requirements if any
            if let requirements = shift.requirements {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text(requirements.joined(separator: ", "))
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.turquoise.opacity(0.8))
            }
            
            // Claim button
            Button(action: { showingConfirmation = true }) {
                Text("Claim Shift")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(shift.isUrgent ? Theme.Colors.warning : Color.clear, lineWidth: 1)
        )
        .alert("Claim This Shift?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Claim") {
                _ = economyManager.claimShift(shift)
            }
        } message: {
            Text("You'll earn \(shift.totalPoints) points. Missing this shift will result in penalties.")
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - My Claims View
struct MyClaimsView: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                if economyManager.myClaims.isEmpty {
                    EmptyStateView(
                        icon: "hand.raised",
                        title: "No Claimed Shifts",
                        message: "Claim shifts to earn points"
                    )
                } else {
                    ForEach(economyManager.myClaims) { claim in
                        ClaimCard(claim: claim)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Claim Card
struct ClaimCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    let claim: ShiftClaim
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Shift Claimed")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text(claim.status.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(statusColor)
            }
            
            Spacer()
            
            Text("+\(claim.pointsAwarded)")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.sunsetOrange)
            
            if claim.status == .claimed {
                Button("Complete") {
                    economyManager.markShiftComplete(claim.id)
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.connected)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var statusColor: Color {
        switch claim.status {
        case .claimed, .inProgress: return Theme.Colors.warning
        case .completed: return Theme.Colors.turquoise
        case .verified: return Theme.Colors.connected
        case .noShow: return Theme.Colors.emergency
        case .cancelled: return Theme.Colors.robotCream.opacity(0.5)
        }
    }
}

// MARK: - Leaderboard View (Anonymous)
struct LeaderboardView: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.sm) {
                Text("Anonymous Rankings")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .padding(.top)
                
                ForEach(economyManager.leaderboard) { entry in
                    LeaderboardRow(entry: entry)
                }
            }
            .padding()
        }
    }
}

// MARK: - Leaderboard Row
struct LeaderboardRow: View {
    let entry: EconomyManager.LeaderboardEntry
    
    var body: some View {
        HStack {
            // Rank
            Text("#\(entry.rank)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(rankColor)
                .frame(width: 40)
            
            // Anonymous indicator
            if entry.isMe {
                Text("You")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            } else {
                Text("Participant")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.points) pts")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("\(entry.shiftsCompleted) shifts")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding()
        .background(entry.isMe ? Theme.Colors.sunsetOrange.opacity(0.2) : Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(entry.isMe ? Theme.Colors.sunsetOrange : Color.clear, lineWidth: 1)
        )
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return Theme.Colors.goldenYellow
        case 2: return Theme.Colors.robotCream
        case 3: return Theme.Colors.sunsetOrange
        default: return Theme.Colors.robotCream.opacity(0.5)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    EconomyDashboardView()
        .environmentObject(EconomyManager())
}
