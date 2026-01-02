import SwiftUI

// MARK: - Contribute View
/// Unified contribution experience - replaces separate Economy and Opportunities views
/// Psychology-informed design: Focus on intrinsic motivation, not competition
/// "Every contribution matters" - celebrate contributors, don't rank them
struct ContributeView: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedFilter: ContributionFilter = .all
    @State private var showingUrgentRequest = false
    
    enum ContributionFilter: String, CaseIterable {
        case all = "All"
        case shifts = "Shifts"
        case tasks = "Tasks"
        case urgent = "Urgent"
    }
    
    var urgentCount: Int {
        let urgentShifts = economyManager.availableShifts.filter { $0.isUrgent }.count
        let urgentTasks = taskManager.tasks.filter { $0.status == .open && $0.priority == .high }.count
        return urgentShifts + urgentTasks
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Your contribution summary (personal progress, not ranking)
                        ContributionSummaryCard()
                        
                        // Urgent help needed banner
                        if urgentCount > 0 {
                            UrgentHelpBanner(count: urgentCount) {
                                selectedFilter = .urgent
                            }
                        }
                        
                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(ContributionFilter.allCases, id: \.self) { filter in
                                    ContributeFilterChip(
                                        title: filter.rawValue,
                                        count: countForFilter(filter),
                                        isSelected: selectedFilter == filter,
                                        isUrgent: filter == .urgent
                                    ) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Ways to contribute
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("WAYS TO CONTRIBUTE")
                                .font(Theme.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                .tracking(0.5)
                                .padding(.horizontal)
                            
                            contributionsList
                        }
                        
                        // Camp superstars (celebration, not ranking)
                        CampSuperstarsCard()
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Request help button (broadcasts to camp)
                    Button(action: { showingUrgentRequest = true }) {
                        Image(systemName: "megaphone.fill")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            .sheet(isPresented: $showingUrgentRequest) {
                RequestHelpSheet()
            }
        }
    }
    
    var contributionsList: some View {
        LazyVStack(spacing: Theme.Spacing.sm) {
            let filteredItems = getFilteredItems()
            
            if filteredItems.isEmpty {
                EmptyContributionsState(filter: selectedFilter)
            } else {
                ForEach(filteredItems) { item in
                    ContributionCard(item: item)
                }
            }
        }
        .padding(.horizontal)
    }
    
    func countForFilter(_ filter: ContributionFilter) -> Int {
        switch filter {
        case .all:
            return economyManager.availableShifts.count + taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }.count
        case .shifts:
            return economyManager.availableShifts.count
        case .tasks:
            return taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }.count
        case .urgent:
            return urgentCount
        }
    }
    
    func getFilteredItems() -> [ContributionItem] {
        var items: [ContributionItem] = []
        
        // Add shifts
        if selectedFilter == .all || selectedFilter == .shifts || selectedFilter == .urgent {
            for shift in economyManager.availableShifts {
                if selectedFilter == .urgent && !shift.isUrgent { continue }
                items.append(ContributionItem(
                    id: shift.id.uuidString,
                    type: .shift,
                    title: shift.location.rawValue,
                    subtitle: formatTime(shift.startTime),
                    points: shift.totalPoints,
                    isUrgent: shift.isUrgent,
                    icon: shift.location.icon,
                    color: Theme.Colors.turquoise,
                    startTime: shift.startTime
                ))
            }
        }
        
        // Add tasks
        if selectedFilter == .all || selectedFilter == .tasks || selectedFilter == .urgent {
            let openTasks = taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
            for task in openTasks {
                if selectedFilter == .urgent && task.priority != .high { continue }
                items.append(ContributionItem(
                    id: task.id.uuidString,
                    type: .task,
                    title: task.title,
                    subtitle: "Task",
                    points: task.pointsValue,
                    isUrgent: task.priority == .high,
                    icon: "checkmark.circle",
                    color: Theme.Colors.sunsetOrange,
                    startTime: nil
                ))
            }
        }
        
        // Sort: urgent first, then by time/priority
        return items.sorted { item1, item2 in
            if item1.isUrgent != item2.isUrgent { return item1.isUrgent }
            if let time1 = item1.startTime, let time2 = item2.startTime {
                return time1 < time2
            }
            return item1.points > item2.points
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Contribution Item
struct ContributionItem: Identifiable {
    let id: String
    let type: ContributionType
    let title: String
    let subtitle: String
    let points: Int
    let isUrgent: Bool
    let icon: String
    let color: Color
    let startTime: Date?
    
    enum ContributionType {
        case shift, task
    }
}

// MARK: - Contribution Summary Card
/// Personal progress, not competitive ranking
struct ContributionSummaryCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR CONTRIBUTION")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    Text(statusMessage)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                Spacer()
                
                // Reliability badge (personal, not comparative)
                ReliabilityBadge(score: economyManager.myStanding.reliabilityScore)
            }
            
            // Stats row (celebrating contribution, not ranking)
            HStack(spacing: Theme.Spacing.lg) {
                ContributionStat(
                    value: "\(economyManager.myStanding.shiftsCompleted)",
                    label: "Contributions",
                    icon: "hand.raised.fill",
                    color: Theme.Colors.turquoise
                )
                
                ContributionStat(
                    value: "\(economyManager.myStanding.pointsEarned)",
                    label: "Points Earned",
                    icon: "star.fill",
                    color: Theme.Colors.goldenYellow
                )
                
                ContributionStat(
                    value: "\(Int(economyManager.myStanding.reliabilityScore * 100))%",
                    label: "Show Rate",
                    icon: "checkmark.seal.fill",
                    color: reliabilityColor
                )
            }
            
            // Progress toward personal goal (not leaderboard position)
            if economyManager.myStanding.pointsRequired > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress toward camp minimum")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        Spacer()
                        Text("\(economyManager.myStanding.pointsEarned)/\(economyManager.myStanding.pointsRequired)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Theme.Colors.backgroundLight)
                                .frame(height: 6)
                                .cornerRadius(3)
                            
                            Rectangle()
                                .fill(progressColor)
                                .frame(width: geometry.size.width * economyManager.myStanding.completionPercentage, height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .padding(.horizontal)
    }
    
    var statusMessage: String {
        let completed = economyManager.myStanding.shiftsCompleted
        if completed == 0 {
            return "Ready to make an impact?"
        } else if completed < 3 {
            return "Great start! Keep it up."
        } else if completed < 10 {
            return "You're making a difference!"
        } else {
            return "Camp hero! 🌟"
        }
    }
    
    var reliabilityColor: Color {
        let score = economyManager.myStanding.reliabilityScore
        if score >= 0.95 { return Theme.Colors.connected }
        if score >= 0.8 { return Theme.Colors.goldenYellow }
        return Theme.Colors.emergency
    }
    
    var progressColor: Color {
        let pct = economyManager.myStanding.completionPercentage
        if pct >= 1.0 { return Theme.Colors.connected }
        if pct >= 0.5 { return Theme.Colors.sunsetOrange }
        return Theme.Colors.goldenYellow
    }
}

// MARK: - Contribution Stat
struct ContributionStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Theme.Colors.robotCream)
            }
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
    }
}

// MARK: - Reliability Badge
struct ReliabilityBadge: View {
    let score: Double
    
    var statusText: String {
        if score >= 0.95 { return "Superstar" }
        if score >= 0.85 { return "Reliable" }
        if score >= 0.7 { return "Improving" }
        return "Needs Work"
    }
    
    var statusColor: Color {
        if score >= 0.95 { return Theme.Colors.connected }
        if score >= 0.85 { return Theme.Colors.turquoise }
        if score >= 0.7 { return Theme.Colors.goldenYellow }
        return Theme.Colors.emergency
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: score >= 0.95 ? "star.fill" : "checkmark.seal")
                .font(.system(size: 12))
            Text(statusText)
                .font(Theme.Typography.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(statusColor.opacity(0.15))
        .cornerRadius(Theme.CornerRadius.full)
    }
}

// MARK: - Urgent Help Banner
struct UrgentHelpBanner: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "bolt.fill")
                    .foregroundColor(Theme.Colors.goldenYellow)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) urgent need\(count == 1 ? "" : "s") right now")
                        .font(Theme.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Camp needs your help!")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            .padding()
            .background(Theme.Colors.goldenYellow.opacity(0.15))
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(Theme.Colors.goldenYellow.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
}

// MARK: - Contribute Filter Chip
struct ContributeFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    var isUrgent: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isUrgent && count > 0 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                }
                Text(title)
                    .font(Theme.Typography.caption)
                if count > 0 {
                    Text("(\(count))")
                        .font(Theme.Typography.caption)
                }
            }
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? (isUrgent && count > 0 ? Theme.Colors.goldenYellow : Theme.Colors.turquoise) : Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Contribution Card
struct ContributionCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var taskManager: TaskManager
    let item: ContributionItem
    @State private var showingConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                // Icon
                Image(systemName: item.icon)
                    .font(.title3)
                    .foregroundColor(item.color)
                    .frame(width: 44, height: 44)
                    .background(item.color.opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.md)
                
                // Details
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.title)
                            .font(Theme.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if item.isUrgent {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 9))
                                Text("URGENT")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.goldenYellow)
                            .cornerRadius(4)
                        }
                    }
                    
                    Text(item.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                Spacer()
                
                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(item.points)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    Text("pts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                }
            }
            
            // Sign up button
            Button(action: { showingConfirmation = true }) {
                Text(item.type == .shift ? "Sign Up" : "I'll Do It")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(item.isUrgent ? Theme.Colors.goldenYellow : Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(item.isUrgent ? Theme.Colors.goldenYellow.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .alert(item.type == .shift ? "Sign Up for This Shift?" : "Take This Task?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(item.type == .shift ? "Sign Up" : "I'll Do It") {
                claimItem()
            }
        } message: {
            Text("You'll earn \(item.points) points. \(item.type == .shift ? "Missing this shift will affect your reliability score." : "")")
        }
    }
    
    func claimItem() {
        if item.type == .shift {
            if let shift = economyManager.availableShifts.first(where: { $0.id.uuidString == item.id }) {
                _ = economyManager.claimShift(shift)
            }
        } else {
            if let task = taskManager.tasks.first(where: { $0.id.uuidString == item.id }) {
                // Claim the task by assigning to current user
                if let index = taskManager.tasks.firstIndex(where: { $0.id.uuidString == item.id }) {
                    taskManager.tasks[index].assignedTo = "!local"
                    taskManager.tasks[index].assignedToName = "You"
                }
            }
        }
    }
}

// MARK: - Camp Superstars Card
/// Celebrates contributors without competitive ranking
struct CampSuperstarsCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.Colors.goldenYellow)
                Text("CAMP SUPERSTARS")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
            }
            
            Text("Celebrating those who make Robot Heart possible")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            
            // Top contributors (celebration, not numbered ranking)
            let topContributors = economyManager.leaderboard.prefix(5)
            ForEach(Array(topContributors.enumerated()), id: \.element.id) { index, entry in
                SuperstarRow(entry: entry, highlight: index == 0)
            }
            
            if economyManager.leaderboard.isEmpty {
                Text("Be the first to contribute!")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .italic()
                    .padding(.vertical)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .padding(.horizontal)
    }
}

// MARK: - Superstar Row
struct SuperstarRow: View {
    let entry: EconomyManager.LeaderboardEntry
    var highlight: Bool = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            Circle()
                .fill(highlight ? Theme.Colors.goldenYellow : Theme.Colors.backgroundLight)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(String(entry.memberName.prefix(2)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(highlight ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                )
            
            // Name and contribution
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.memberName)
                        .font(Theme.Typography.callout)
                        .fontWeight(highlight ? .semibold : .regular)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if highlight {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.goldenYellow)
                    }
                }
                
                Text("\(entry.shiftsCompleted) contributions")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Spacer()
            
            // Reliability indicator (not points - focus on dependability)
            if entry.reliability >= 0.95 {
                Text("Never missed")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.connected)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Empty Contributions State
struct EmptyContributionsState: View {
    let filter: ContributeView.ContributionFilter
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: filter == .urgent ? "checkmark.circle" : "hands.clap")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.connected)
            
            Text(filter == .urgent ? "No urgent needs right now!" : "All caught up!")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("The camp is running smoothly. Check back later.")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 60)
    }
}

// MARK: - Request Help Sheet
/// Broadcast an urgent help request to the camp with a timer
struct RequestHelpSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var helpDescription = ""
    @State private var selectedArea: TaskArea = .general
    @State private var urgencyMinutes = 30
    @State private var showingConfirmation = false
    
    let urgencyOptions = [15, 30, 60, 120]
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Header
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.sunsetOrange)
                            
                            Text("Request Help")
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Text("This will broadcast to the camp channel and create an urgent task")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        
                        // What do you need help with?
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("What do you need?")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            TextField("e.g., Need help carrying ice to camp", text: $helpDescription, axis: .vertical)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream)
                                .padding()
                                .background(Theme.Colors.backgroundLight)
                                .cornerRadius(Theme.CornerRadius.md)
                                .lineLimit(3...6)
                        }
                        .padding(.horizontal)
                        
                        // Area
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Area")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.Spacing.sm) {
                                    ForEach(TaskArea.defaults, id: \.id) { area in
                                        Button(action: { selectedArea = area }) {
                                            Text(area.name)
                                                .font(Theme.Typography.caption)
                                                .foregroundColor(selectedArea.id == area.id ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                                                .padding(.horizontal, Theme.Spacing.md)
                                                .padding(.vertical, Theme.Spacing.xs)
                                                .background(selectedArea.id == area.id ? Theme.Colors.turquoise : Theme.Colors.backgroundLight)
                                                .cornerRadius(Theme.CornerRadius.full)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // How urgent?
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("How soon do you need help?")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(urgencyOptions, id: \.self) { minutes in
                                    Button(action: { urgencyMinutes = minutes }) {
                                        Text(formatMinutes(minutes))
                                            .font(Theme.Typography.caption)
                                            .fontWeight(urgencyMinutes == minutes ? .semibold : .regular)
                                            .foregroundColor(urgencyMinutes == minutes ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                                            .padding(.horizontal, Theme.Spacing.md)
                                            .padding(.vertical, Theme.Spacing.sm)
                                            .background(urgencyMinutes == minutes ? Theme.Colors.goldenYellow : Theme.Colors.backgroundLight)
                                            .cornerRadius(Theme.CornerRadius.md)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                        
                        // Send button
                        Button(action: { showingConfirmation = true }) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Broadcast to Camp")
                            }
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(helpDescription.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .disabled(helpDescription.isEmpty)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Request Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
            .alert("Broadcast Help Request?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Send") {
                    sendHelpRequest()
                    dismiss()
                }
            } message: {
                Text("This will send a message to the camp channel and create an urgent task.")
            }
        }
    }
    
    func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            return "\(minutes / 60) hr"
        }
    }
    
    func sendHelpRequest() {
        // 1. Send message to camp channel
        let message = "🆘 HELP NEEDED: \(helpDescription) [\(selectedArea.name)] - Need help within \(formatMinutes(urgencyMinutes))"
        meshtasticManager.sendMessage(message)
        
        // 2. Create urgent task
        let task = AdHocTask(
            title: helpDescription,
            description: "Urgent help request broadcast to camp",
            areaID: selectedArea.id,
            priority: .high,
            createdBy: "!local",
            createdByName: "You"
        )
        taskManager.tasks.append(task)
    }
}

#Preview {
    ContributeView()
        .environmentObject(EconomyManager())
        .environmentObject(TaskManager())
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
}
