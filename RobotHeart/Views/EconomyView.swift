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
                    
                    Text("burn")
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

// MARK: - Leaderboard View (Accountability & Social Capital)
struct LeaderboardView: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                // Social capital explanation
                SocialCapitalHeader()
                
                // Camp accountability leaderboard
                CampLeaderboardSection()
                
                // Trusted network section
                TrustedNetworkSection()
            }
            .padding()
        }
    }
}

// MARK: - Social Capital Header
struct SocialCapitalHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                Text("Social Capital")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Text("Your contributions build trust that carries across events, year-round. Reliable people find each other.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.sunsetOrange.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Trusted Network Section
struct TrustedNetworkSection: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    // Filter for superstars and reliable members
    var trustedMembers: [EconomyManager.LeaderboardEntry] {
        economyManager.leaderboard.filter { entry in
            // Consider someone "trusted" if they have good reliability
            entry.shiftsCompleted >= 3
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "person.2.badge.gearshape.fill")
                    .foregroundColor(Theme.Colors.turquoise)
                Text("Trusted Network")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text("\(trustedMembers.count) members")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Text("People who consistently show up. This reputation carries to future events.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            
            if trustedMembers.isEmpty {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.Colors.goldenYellow)
                    Text("Complete shifts to join the trusted network")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.md)
            } else {
                // Show trusted members with their reliability badges
                ForEach(trustedMembers.prefix(5)) { member in
                    TrustedMemberRow(entry: member)
                }
                
                if trustedMembers.count > 5 {
                    Text("+ \(trustedMembers.count - 5) more trusted members")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Trusted Member Row
struct TrustedMemberRow: View {
    let entry: EconomyManager.LeaderboardEntry
    
    var reliabilityBadge: (text: String, color: Color) {
        switch entry.shiftsCompleted {
        case 10...: return ("⭐ Superstar", Theme.Colors.goldenYellow)
        case 5..<10: return ("Reliable", Theme.Colors.connected)
        case 3..<5: return ("Contributing", Theme.Colors.turquoise)
        default: return ("New", Theme.Colors.robotCream.opacity(0.5))
        }
    }
    
    var body: some View {
        HStack {
            // Avatar placeholder
            Circle()
                .fill(entry.isMe ? Theme.Colors.sunsetOrange.opacity(0.3) : Theme.Colors.turquoise.opacity(0.3))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(entry.isMe ? "You" : "")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isMe ? "You" : "Camp Member")
                    .font(Theme.Typography.callout)
                    .foregroundColor(entry.isMe ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
                
                Text(reliabilityBadge.text)
                    .font(Theme.Typography.caption)
                    .foregroundColor(reliabilityBadge.color)
            }
            
            Spacer()
            
            // Contribution stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.shiftsCompleted) shifts")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("\(entry.points) pts")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding(Theme.Spacing.sm)
        .background(entry.isMe ? Theme.Colors.sunsetOrange.opacity(0.1) : Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Camp Leaderboard Section
struct CampLeaderboardSection: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    // Find my position
    var myRank: Int {
        economyManager.leaderboard.first(where: { $0.isMe })?.rank ?? 0
    }
    
    // Top 3 for podium
    var topThree: [EconomyManager.LeaderboardEntry] {
        Array(economyManager.leaderboard.prefix(3))
    }
    
    // Rest of leaderboard
    var restOfLeaderboard: [EconomyManager.LeaderboardEntry] {
        Array(economyManager.leaderboard.dropFirst(3))
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // My position highlight
            if myRank > 0 {
                MyRankCard(rank: myRank, totalParticipants: economyManager.leaderboard.count)
            }
            
            // Podium for top 3
            if topThree.count >= 3 {
                LeaderboardPodium(entries: topThree)
            }
            
            // Stats summary
            LeaderboardStats()
            
            // Full rankings
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Full Rankings")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                ForEach(economyManager.leaderboard) { entry in
                    LeaderboardRow(entry: entry)
                }
            }
        }
    }
}

// MARK: - My Rank Card
struct MyRankCard: View {
    let rank: Int
    let totalParticipants: Int
    
    var percentile: Int {
        guard totalParticipants > 0 else { return 0 }
        return Int((1.0 - Double(rank - 1) / Double(totalParticipants)) * 100)
    }
    
    var motivationalText: String {
        switch rank {
        case 1: return "🏆 You're the champion!"
        case 2: return "🥈 So close to the top!"
        case 3: return "🥉 On the podium!"
        case 4...10: return "🔥 Top 10! Keep pushing!"
        default: return "💪 Every shift counts!"
        }
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR RANK")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("#\(rank)")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundColor(rank <= 3 ? Theme.Colors.goldenYellow : Theme.Colors.sunsetOrange)
                        
                        Text("of \(totalParticipants)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Percentile badge
                VStack(spacing: 2) {
                    Text("Top")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    Text("\(100 - percentile + 1)%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.turquoise)
                }
                .padding()
                .background(Theme.Colors.turquoise.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            Text(motivationalText)
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.robotCream)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.sunsetOrange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Leaderboard Podium
struct LeaderboardPodium: View {
    let entries: [EconomyManager.LeaderboardEntry]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.sm) {
            // 2nd place
            if entries.count > 1 {
                PodiumSpot(entry: entries[1], height: 80, medal: "🥈")
            }
            
            // 1st place
            if entries.count > 0 {
                PodiumSpot(entry: entries[0], height: 100, medal: "🏆")
            }
            
            // 3rd place
            if entries.count > 2 {
                PodiumSpot(entry: entries[2], height: 60, medal: "🥉")
            }
        }
        .padding(.vertical, Theme.Spacing.md)
    }
}

// MARK: - Podium Spot
struct PodiumSpot: View {
    let entry: EconomyManager.LeaderboardEntry
    let height: CGFloat
    let medal: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(medal)
                .font(.system(size: 28))
            
            Text(entry.isMe ? "You" : "Camper")
                .font(Theme.Typography.caption)
                .foregroundColor(entry.isMe ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
                .lineLimit(1)
            
            Text("\(entry.points)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("pts")
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            
            Rectangle()
                .fill(entry.isMe ? Theme.Colors.sunsetOrange : Theme.Colors.turquoise)
                .frame(height: height)
                .cornerRadius(Theme.CornerRadius.sm, corners: [.topLeft, .topRight])
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Stats
struct LeaderboardStats: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var totalPoints: Int {
        economyManager.leaderboard.reduce(0) { $0 + $1.points }
    }
    
    var totalShifts: Int {
        economyManager.leaderboard.reduce(0) { $0 + $1.shiftsCompleted }
    }
    
    var avgPoints: Int {
        guard !economyManager.leaderboard.isEmpty else { return 0 }
        return totalPoints / economyManager.leaderboard.count
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            LeaderboardStatItem(value: "\(economyManager.leaderboard.count)", label: "Participants", icon: "person.3.fill")
            LeaderboardStatItem(value: "\(totalShifts)", label: "Shifts Done", icon: "checkmark.circle.fill")
            LeaderboardStatItem(value: "\(avgPoints)", label: "Avg Points", icon: "chart.bar.fill")
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Leaderboard Stat Item
struct LeaderboardStatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.turquoise)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.robotCream)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
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
