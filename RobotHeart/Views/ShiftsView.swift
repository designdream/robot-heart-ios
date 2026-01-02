import SwiftUI

struct ShiftsView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var draftManager: DraftManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingAdminView = false
    @State private var showingAddTask = false
    @State private var showingOpportunities = false
    @State private var showingCampMap = false
    
    // Calculate total commitments
    var totalCommitments: Int {
        shiftManager.myShifts.count + taskManager.myTasks.count
    }
    
    // Calculate upcoming commitments (next 24 hours)
    var urgentCommitments: Int {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let urgentShifts = shiftManager.myShifts.filter { $0.startTime < tomorrow && $0.startTime > Date() }
        let urgentTasks = taskManager.myTasks.filter { $0.priority == .high }
        return urgentShifts.count + urgentTasks.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MY BURN = "Everything about my participation"
                    // What I'm doing + What I can do
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            // SECTION 1: Active/Current commitment (if any)
                            if let activeShift = shiftManager.activeShifts.first {
                                ActiveCommitmentCard(shift: activeShift)
                            }
                            
                            // SECTION 2: Today's commitments with time-to-leave
                            TodaysCommitmentsSection()
                            
                            // SECTION 3: Upcoming commitments
                            UpcomingCommitmentsSection()
                            
                            // SECTION 4: Ways to Contribute (inline, not sheet)
                            // Merged from ContributeView - this is action-oriented
                            WaysToContributeSection()
                            
                            // NOTE: Camp Superstars removed - clutters minimalist design
                            // Celebration of contributors can be accessed via ContributeView sheet if needed
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("My Burn")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: Theme.Spacing.sm) {
                        // Camp Map
                        Button(action: { showingCampMap = true }) {
                            Image(systemName: "map.fill")
                                .foregroundColor(Theme.Colors.turquoise)
                        }
                        
                        // Admin
                        if shiftManager.isAdmin {
                            Button(action: { showingAdminView = true }) {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAdminView) {
                ShiftAdminView()
                    .environmentObject(shiftManager)
                    .environmentObject(meshtasticManager)
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(preselectedArea: nil)
            }
            .sheet(isPresented: $showingOpportunities) {
                ContributeView()
            }
            .sheet(isPresented: $showingCampMap) {
                CampBrowserView()
            }
            .onAppear {
                economyManager.refreshAvailableShifts()
            }
        }
    }
    
    var potentialPoints: Int {
        let shiftPoints = economyManager.availableShifts.reduce(0) { $0 + $1.totalPoints }
        let taskPoints = taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
            .reduce(0) { $0 + $1.pointsValue }
        return shiftPoints + taskPoints
    }
    
    // MARK: - Shifts Content
    private var shiftsContent: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Active draft banner (if one is live)
                if let activeDraft = draftManager.activeDraft {
                    NavigationLink(destination: LiveDraftView(draft: activeDraft)) {
                        ActiveDraftBannerCompact(draft: activeDraft)
                    }
                }
                
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
                
                // Available shifts to claim
                if !economyManager.availableShifts.isEmpty {
                    AvailableShiftsSection()
                }
                
                // No shifts placeholder
                if shiftManager.myShifts.isEmpty && economyManager.availableShifts.isEmpty {
                    NoShiftsView()
                } else {
                    // Upcoming shifts
                    if !shiftManager.upcomingShifts.isEmpty {
                        ShiftSection(
                            title: "My Upcoming Shifts",
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
    
    // MARK: - Tasks Content
    private var tasksContent: some View {
        VStack(spacing: 0) {
            // Critical tasks banner
            if taskManager.highPriorityCount > 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Theme.Colors.emergency)
                    Text("\(taskManager.highPriorityCount) critical task\(taskManager.highPriorityCount == 1 ? "" : "s") need attention")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                    Spacer()
                }
                .padding()
                .background(Theme.Colors.emergency.opacity(0.2))
            }
            
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // My assigned tasks
                    if !taskManager.myTasks.isEmpty {
                        TaskSectionView(title: "My Tasks", tasks: taskManager.myTasks, showPoints: true)
                    }
                    
                    // Open tasks to claim
                    let openTasks = taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
                    if !openTasks.isEmpty {
                        TaskSectionView(title: "Available Tasks", tasks: Array(openTasks.prefix(5)), showPoints: true)
                    }
                    
                    // Empty state
                    if taskManager.myTasks.isEmpty && openTasks.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.connected)
                            Text("All caught up!")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            Text("No tasks need your attention right now")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                        .padding(.top, 60)
                    }
                    
                    // Link to full tasks view
                    NavigationLink(destination: TasksHubView()) {
                        HStack {
                            Text("View All Tasks")
                            Image(systemName: "arrow.right")
                        }
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                    .padding(.top, Theme.Spacing.lg)
                }
                .padding()
            }
            
            // Add task button
            Button(action: { showingAddTask = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Task")
                }
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Colors.sunsetOrange)
            }
        }
    }
}

// MARK: - Task Section View (for Shifts tab)
struct TaskSectionView: View {
    let title: String
    let tasks: [AdHocTask]
    var showPoints: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            ForEach(tasks) { task in
                TaskRowCompact(task: task, showPoints: showPoints)
            }
        }
    }
}

// MARK: - Task Row Compact
struct TaskRowCompact: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: AdHocTask
    var showPoints: Bool = false
    
    var body: some View {
        HStack {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Text(task.priority.shortLabel)
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            if showPoints {
                Text("+\(task.pointsValue) pts")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            // Claim/Complete button
            if task.assignedTo == nil {
                Button("Claim") {
                    taskManager.claimTask(task.id, memberName: "Me")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.turquoise)
                .cornerRadius(Theme.CornerRadius.sm)
            } else if task.status != .completed {
                Button("Done") {
                    taskManager.completeTask(task.id, completedByName: "Me")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Theme.Colors.connected)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .high: return Theme.Colors.emergency
        case .medium: return Theme.Colors.warning
        case .low: return Theme.Colors.turquoise
        }
    }
}

// MARK: - Shift Points Card (Primary incentive)
struct ShiftPointsCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var taskManager: TaskManager
    
    // Calculate potential points from available shifts
    var potentialShiftPoints: Int {
        economyManager.availableShifts.reduce(0) { $0 + $1.totalPoints }
    }
    
    // Calculate potential points from open tasks
    var potentialTaskPoints: Int {
        taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
            .reduce(0) { $0 + $1.pointsValue }
    }
    
    var totalPotentialPoints: Int {
        potentialShiftPoints + potentialTaskPoints
    }
    
    // My rank in the leaderboard
    var myRank: Int {
        let myEntry = economyManager.leaderboard.first { $0.isMe }
        return myEntry?.rank ?? 1
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MY POINTS")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(economyManager.myStanding.pointsEarned)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        
                        Text("/ \(economyManager.myStanding.pointsRequired)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Status badge based on reliability
                    Text(economyManager.myStanding.reliabilityScore >= 0.9 ? "⭐ Superstar" : 
                         economyManager.myStanding.reliabilityScore >= 0.7 ? "Reliable" : "Needs Improvement")
                        .font(Theme.Typography.caption)
                        .foregroundColor(economyManager.myStanding.reliabilityScore >= 0.9 ? Theme.Colors.goldenYellow : Theme.Colors.robotCream)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(economyManager.myStanding.reliabilityScore >= 0.9 ? Theme.Colors.goldenYellow.opacity(0.2) : Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.sm)
                }
                
                Spacer()
                
                // Progress ring with rank
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Theme.Colors.backgroundLight, lineWidth: 8)
                            .frame(width: 70, height: 70)
                        
                        Circle()
                            .trim(from: 0, to: economyManager.myStanding.completionPercentage)
                            .stroke(Theme.Colors.sunsetOrange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 70, height: 70)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(economyManager.myStanding.completionPercentage * 100))%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    
                    // Rank badge
                    HStack(spacing: 2) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                        Text("#\(myRank)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(myRank <= 3 ? Theme.Colors.goldenYellow : Theme.Colors.turquoise)
                }
            }
            
            // Potential points banner (if there are opportunities)
            if totalPotentialPoints > 0 {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.Colors.goldenYellow)
                    
                    Text("**+\(totalPotentialPoints) pts** available to earn!")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Spacer()
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        if potentialShiftPoints > 0 {
                            Label("\(potentialShiftPoints)", systemImage: "calendar")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.turquoise)
                        }
                        if potentialTaskPoints > 0 {
                            Label("\(potentialTaskPoints)", systemImage: "checkmark.circle")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.goldenYellow.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.sm)
            }
            
            // Quick stats
            HStack(spacing: Theme.Spacing.lg) {
                PointsStatItem(value: "\(economyManager.myClaims.count)", label: "Claimed", icon: "hand.raised.fill")
                PointsStatItem(value: "\(economyManager.myStanding.shiftsCompleted)", label: "Completed", icon: "checkmark.circle.fill")
                PointsStatItem(value: "#\(myRank)", label: "Rank", icon: "trophy.fill")
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Points Stat Item
struct PointsStatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Theme.Colors.turquoise)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Theme.Colors.robotCream)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Draft Banner (Compact)
struct ActiveDraftBannerCompact: View {
    let draft: ShiftDraft
    
    var body: some View {
        HStack {
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.connected)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE DRAFT")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.connected)
                Text(draft.name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .padding()
        .background(Theme.Colors.connected.opacity(0.15))
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.connected.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Available Shifts Section
struct AvailableShiftsSection: View {
    @EnvironmentObject var economyManager: EconomyManager
    @State private var showingAll = false
    
    var displayedShifts: [AnonymousShift] {
        showingAll ? economyManager.availableShifts : Array(economyManager.availableShifts.prefix(3))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Available Shifts")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                if economyManager.availableShifts.count > 3 {
                    Button(showingAll ? "Show Less" : "See All (\(economyManager.availableShifts.count))") {
                        withAnimation { showingAll.toggle() }
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            
            ForEach(displayedShifts) { shift in
                AvailableShiftRow(shift: shift)
            }
        }
    }
}

// MARK: - Available Shift Row
struct AvailableShiftRow: View {
    @EnvironmentObject var economyManager: EconomyManager
    let shift: AnonymousShift
    @State private var showingConfirm = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.location.rawValue)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Label(shift.location.rawValue, systemImage: "mappin")
                    Label(formatShiftDate(shift.startTime), systemImage: "calendar")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            Button(action: { showingConfirm = true }) {
                HStack(spacing: 4) {
                    Text("+\(shift.totalPoints)")
                        .font(.system(size: 14, weight: .bold))
                    Text("pts")
                        .font(.system(size: 10))
                }
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
        .alert("Claim This Shift?", isPresented: $showingConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Claim +\(shift.totalPoints) pts") {
                _ = economyManager.claimShift(shift)
            }
        } message: {
            Text("\(shift.location.rawValue)\n\(formatShiftDate(shift.startTime))")
        }
    }
    
    private func formatShiftDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// Helper function for formatting shift dates
private func formatShiftDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
    return formatter.string(from: date)
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

// MARK: - My Commitments Status Card
struct MyCommitmentsStatusCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    let totalCommitments: Int
    let urgentCount: Int
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR CONTRIBUTION")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(economyManager.myStanding.pointsEarned)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        
                        Text("Social Capital")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Trust level badge
                VStack(spacing: 4) {
                    Image(systemName: trustIcon)
                        .font(.system(size: 28))
                        .foregroundColor(trustColor)
                    Text(trustLevel)
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(trustColor)
                }
                .padding(Theme.Spacing.sm)
                .background(trustColor.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            // Commitments summary
            if totalCommitments > 0 {
                HStack(spacing: Theme.Spacing.lg) {
                    CommitmentStat(
                        value: "\(totalCommitments)",
                        label: "Commitments",
                        icon: "checkmark.circle.fill",
                        color: Theme.Colors.turquoise
                    )
                    
                    if urgentCount > 0 {
                        CommitmentStat(
                            value: "\(urgentCount)",
                            label: "Coming Up",
                            icon: "clock.fill",
                            color: Theme.Colors.goldenYellow
                        )
                    }
                    
                    CommitmentStat(
                        value: "#\(myRank)",
                        label: "Camp Rank",
                        icon: "trophy.fill",
                        color: myRank <= 3 ? Theme.Colors.goldenYellow : Theme.Colors.robotCream.opacity(0.6)
                    )
                }
            } else {
                // No commitments yet - motivational message
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.Colors.goldenYellow)
                    Text("Ready to contribute? Browse opportunities below!")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                }
                .padding(Theme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.goldenYellow.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    var myRank: Int {
        economyManager.leaderboard.first { $0.isMe }?.rank ?? 1
    }
    
    var trustLevel: String {
        let score = economyManager.myStanding.reliabilityScore
        if score >= 0.9 { return "Legendary" }
        if score >= 0.8 { return "Superstar" }
        if score >= 0.7 { return "Reliable" }
        if score >= 0.5 { return "Contributing" }
        return "New"
    }
    
    var trustIcon: String {
        let score = economyManager.myStanding.reliabilityScore
        if score >= 0.9 { return "star.circle.fill" }
        if score >= 0.8 { return "star.fill" }
        if score >= 0.7 { return "checkmark.seal.fill" }
        return "person.crop.circle.fill"
    }
    
    var trustColor: Color {
        let score = economyManager.myStanding.reliabilityScore
        if score >= 0.9 { return Theme.Colors.goldenYellow }
        if score >= 0.8 { return Theme.Colors.sunsetOrange }
        if score >= 0.7 { return Theme.Colors.turquoise }
        return Theme.Colors.robotCream.opacity(0.6)
    }
}

// MARK: - Commitment Stat
struct CommitmentStat: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.robotCream)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Active Commitment Card
struct ActiveCommitmentCard: View {
    let shift: Shift
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label("HAPPENING NOW", systemImage: "bolt.fill")
                    .font(Theme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.connected)
                Spacer()
                Text(timeRemaining)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: shift.location.icon)
                    .font(.title)
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .frame(width: 50, height: 50)
                    .background(Theme.Colors.sunsetOrange.opacity(0.2))
                    .cornerRadius(Theme.CornerRadius.md)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(shift.notes ?? "General")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                // Points badge
                VStack {
                    Text("+\(pointsForLocation(shift.location))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    Text("pts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Theme.Colors.connected.opacity(0.2), Theme.Colors.backgroundMedium],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.connected.opacity(0.3), lineWidth: 1)
        )
    }
    
    var timeRemaining: String {
        let remaining = shift.endTime.timeIntervalSince(Date())
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }
    
    func pointsForLocation(_ location: Shift.ShiftLocation) -> Int {
        switch location {
        case .bus: return ShiftEconomy.PointValues.busShift
        case .shadyBot: return ShiftEconomy.PointValues.shadyBotShift
        case .camp: return ShiftEconomy.PointValues.campShift
        }
    }
}

// MARK: - Today's Commitments Section
struct TodaysCommitmentsSection: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var taskManager: TaskManager
    
    var todaysShifts: [Shift] {
        let calendar = Calendar.current
        return shiftManager.myShifts.filter { calendar.isDateInToday($0.startTime) }
    }
    
    var todaysTasks: [AdHocTask] {
        taskManager.myTasks.filter { $0.priority == .high }
    }
    
    var body: some View {
        if !todaysShifts.isEmpty || !todaysTasks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("TODAY")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
                
                ForEach(todaysShifts) { shift in
                    ShiftCommitmentRow(
                        icon: shift.location.icon,
                        title: shift.location.rawValue,
                        subtitle: formatTime(shift.startTime),
                        points: pointsForLocation(shift.location),
                        type: .shift,
                        isUrgent: shift.startTime < Date().addingTimeInterval(3600),
                        startTime: shift.startTime
                    )
                }
                
                ForEach(todaysTasks) { task in
                    ShiftCommitmentRow(
                        icon: "checkmark.circle",
                        title: task.title,
                        subtitle: task.priority.shortLabel,
                        points: task.priority.points,
                        type: .task,
                        isUrgent: task.priority == .high
                    )
                }
            }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    func pointsForLocation(_ location: Shift.ShiftLocation) -> Int {
        switch location {
        case .bus: return ShiftEconomy.PointValues.busShift
        case .shadyBot: return ShiftEconomy.PointValues.shadyBotShift
        case .camp: return ShiftEconomy.PointValues.campShift
        }
    }
}

// MARK: - Upcoming Commitments Section
struct UpcomingCommitmentsSection: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var taskManager: TaskManager
    
    var upcomingShifts: [Shift] {
        let calendar = Calendar.current
        return shiftManager.myShifts
            .filter { !calendar.isDateInToday($0.startTime) && $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        if !upcomingShifts.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("UPCOMING")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
                
                ForEach(upcomingShifts) { shift in
                    ShiftCommitmentRow(
                        icon: shift.location.icon,
                        title: shift.location.rawValue,
                        subtitle: formatDate(shift.startTime),
                        points: pointsForLocation(shift.location),
                        type: .shift,
                        isUrgent: false
                    )
                }
            }
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    func pointsForLocation(_ location: Shift.ShiftLocation) -> Int {
        switch location {
        case .bus: return ShiftEconomy.PointValues.busShift
        case .shadyBot: return ShiftEconomy.PointValues.shadyBotShift
        case .camp: return ShiftEconomy.PointValues.campShift
        }
    }
}

// MARK: - Shift Commitment Row
struct ShiftCommitmentRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let points: Int
    let type: ShiftCommitmentType
    let isUrgent: Bool
    var startTime: Date? = nil
    var locationDistance: Double? = nil // Distance in meters
    
    enum ShiftCommitmentType {
        case shift, task
    }
    
    // Playa bike speed limit is 5 mph (~2.2 m/s) - most people bike
    // Walking is ~2 mph (~0.9 m/s) but we assume biking as default
    private let playaBikeSpeedMPS: Double = 2.2 // 5 mph, playa speed limit
    
    // Calculate time to leave
    var timeToLeave: (minutes: Int, status: LeaveStatus)? {
        guard let start = startTime else { return nil }
        
        let now = Date()
        let timeUntilStart = start.timeIntervalSince(now)
        
        // Estimate travel time (default 10 min if no GPS)
        let travelTimeSeconds: Double
        if let distance = locationDistance {
            travelTimeSeconds = distance / playaBikeSpeedMPS
        } else {
            travelTimeSeconds = 600 // Default 10 min buffer
        }
        
        let leaveInSeconds = timeUntilStart - travelTimeSeconds - 300 // 5 min buffer
        let leaveInMinutes = Int(leaveInSeconds / 60)
        
        if leaveInMinutes < 0 {
            return (abs(leaveInMinutes), .late)
        } else if leaveInMinutes < 5 {
            return (leaveInMinutes, .leaveNow)
        } else if leaveInMinutes < 15 {
            return (leaveInMinutes, .soon)
        } else {
            return (leaveInMinutes, .plenty)
        }
    }
    
    enum LeaveStatus {
        case plenty, soon, leaveNow, late
        
        var color: Color {
            switch self {
            case .plenty: return Theme.Colors.connected
            case .soon: return Theme.Colors.goldenYellow
            case .leaveNow: return Theme.Colors.sunsetOrange
            case .late: return Theme.Colors.emergency
            }
        }
        
        var icon: String {
            switch self {
            case .plenty: return "checkmark.circle"
            case .soon: return "clock"
            case .leaveNow: return "figure.walk"
            case .late: return "exclamationmark.triangle"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(type == .shift ? Theme.Colors.turquoise : Theme.Colors.sunsetOrange)
                    .frame(width: 40, height: 40)
                    .background((type == .shift ? Theme.Colors.turquoise : Theme.Colors.sunsetOrange).opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.sm)
                
                // Details
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(Theme.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if isUrgent {
                            Text("SOON")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Theme.Colors.backgroundDark)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.goldenYellow)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                Spacer()
                
                // Points
                Text("+\(points)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            .padding(Theme.Spacing.md)
            
            // Time to leave indicator (only for shifts with start time)
            if let (minutes, status) = timeToLeave {
                Divider()
                    .background(Theme.Colors.robotCream.opacity(0.1))
                
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: status.icon)
                        .font(.system(size: 12))
                        .foregroundColor(status.color)
                    
                    switch status {
                    case .late:
                        Text("You should have left \(minutes) min ago!")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(status.color)
                    case .leaveNow:
                        Text("Leave now to be on time")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(status.color)
                    case .soon:
                        Text("Leave in \(minutes) min")
                            .font(Theme.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(status.color)
                    case .plenty:
                        Text("\(minutes) min until you need to leave")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Spacer()
                    
                    // Distance if available
                    if let distance = locationDistance {
                        Text(formatDistance(distance))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                    }
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(status == .late || status == .leaveNow ? status.color.opacity(0.1) : Color.clear)
            }
        }
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m away"
        } else {
            return String(format: "%.1fkm away", meters / 1000)
        }
    }
}

// MARK: - Opportunities CTA Card
struct OpportunitiesCTACard: View {
    let availableShifts: Int
    let availableTasks: Int
    let potentialPoints: Int
    let action: () -> Void
    
    var totalOpportunities: Int {
        availableShifts + availableTasks
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GROW YOUR IMPACT")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.goldenYellow)
                            .tracking(0.5)
                        
                        Text("Browse Opportunities")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
                
                if totalOpportunities > 0 {
                    HStack(spacing: Theme.Spacing.lg) {
                        if availableShifts > 0 {
                            Label("\(availableShifts) shifts", systemImage: "calendar")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.turquoise)
                        }
                        
                        if availableTasks > 0 {
                            Label("\(availableTasks) tasks", systemImage: "checkmark.circle")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                        
                        Spacer()
                        
                        Text("+\(potentialPoints) pts available")
                            .font(Theme.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundColor(Theme.Colors.goldenYellow)
                    }
                } else {
                    Text("Check back later for new opportunities")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            .padding(Theme.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [Theme.Colors.sunsetOrange.opacity(0.15), Theme.Colors.backgroundMedium],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(Theme.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(Theme.Colors.sunsetOrange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Ways to Contribute Section (Inline in My Burn)
struct WaysToContributeSection: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingAll = false
    
    var availableShifts: [AnonymousShift] {
        economyManager.availableShifts
    }
    
    var availableTasks: [AdHocTask] {
        taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
    }
    
    var urgentCount: Int {
        let urgentShifts = availableShifts.filter { $0.isUrgent }.count
        let urgentTasks = availableTasks.filter { $0.priority == .high }.count
        return urgentShifts + urgentTasks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(Theme.Colors.turquoise)
                Text("WAYS TO BURN MORE")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
                
                Spacer()
                
                if urgentCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("\(urgentCount) urgent")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.goldenYellow)
                }
            }
            
            if availableShifts.isEmpty && availableTasks.isEmpty {
                // All caught up
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(Theme.Colors.connected)
                    Text("All caught up! Check back later.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                .padding()
            } else {
                // Show first few opportunities
                let shiftsToShow = showingAll ? availableShifts : Array(availableShifts.prefix(2))
                let tasksToShow = showingAll ? availableTasks : Array(availableTasks.prefix(2))
                
                ForEach(shiftsToShow) { shift in
                    InlineOpportunityRow(
                        icon: shift.location.icon,
                        title: shift.location.rawValue,
                        subtitle: formatTime(shift.startTime),
                        burn: shift.totalPoints,
                        isUrgent: shift.isUrgent,
                        type: .shift
                    ) {
                        _ = economyManager.claimShift(shift)
                    }
                }
                
                ForEach(tasksToShow) { task in
                    InlineOpportunityRow(
                        icon: "checkmark.circle",
                        title: task.title,
                        subtitle: task.priority.shortLabel,
                        burn: task.pointsValue,
                        isUrgent: task.priority == .high,
                        type: .task
                    ) {
                        if let index = taskManager.tasks.firstIndex(where: { $0.id == task.id }) {
                            taskManager.tasks[index].assignedTo = "!local"
                            taskManager.tasks[index].assignedToName = "You"
                        }
                    }
                }
                
                // Show more button
                let totalCount = availableShifts.count + availableTasks.count
                if totalCount > 4 && !showingAll {
                    Button(action: { showingAll = true }) {
                        HStack {
                            Text("Show all \(totalCount) opportunities")
                            Image(systemName: "chevron.down")
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Inline Opportunity Row
struct InlineOpportunityRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let burn: Int
    let isUrgent: Bool
    let type: OpportunityType
    let action: () -> Void
    
    enum OpportunityType {
        case shift, task
    }
    
    @State private var showingConfirmation = false
    
    var color: Color {
        type == .shift ? Theme.Colors.turquoise : Theme.Colors.sunsetOrange
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.sm)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                        .lineLimit(1)
                    
                    if isUrgent {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.goldenYellow)
                    }
                }
                
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Spacer()
            
            // Burn + Sign up
            Button(action: { showingConfirmation = true }) {
                HStack(spacing: 4) {
                    Text("+\(burn)")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                }
                .foregroundColor(isUrgent ? Theme.Colors.backgroundDark : Theme.Colors.sunsetOrange)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(isUrgent ? Theme.Colors.goldenYellow : Theme.Colors.sunsetOrange.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.full)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
        .alert(type == .shift ? "Sign Up?" : "Take This Task?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button(type == .shift ? "Sign Up" : "I'll Do It") {
                action()
            }
        } message: {
            Text("You'll earn \(burn) burn for this.")
        }
    }
}

// MARK: - Camp Superstars Section (Celebration, not ranking)
struct CampSuperstarsSection: View {
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
            
            if economyManager.leaderboard.isEmpty {
                Text("Be the first to contribute!")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .italic()
                    .padding()
            } else {
                // Top 5 contributors (celebration, not numbered ranking)
                ForEach(Array(economyManager.leaderboard.prefix(5).enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: Theme.Spacing.md) {
                        // Avatar
                        Circle()
                            .fill(index == 0 ? Theme.Colors.goldenYellow : Theme.Colors.backgroundLight)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(String(entry.memberName.prefix(2)).uppercased())
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(index == 0 ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(entry.memberName)
                                    .font(Theme.Typography.callout)
                                    .fontWeight(index == 0 ? .semibold : .regular)
                                    .foregroundColor(Theme.Colors.robotCream)
                                
                                if index == 0 {
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
                        
                        // Reliability (not points - focus on dependability)
                        if entry.reliability >= 0.95 {
                            Text("Never missed")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.connected)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Opportunities Marketplace View (Legacy - kept for compatibility)
struct OpportunitiesMarketplaceView: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var shiftManager: ShiftManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Motivational header
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("Every contribution matters")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("Build your legacy. Earn Social Capital. Be remembered.")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.backgroundMedium)
                    
                    // Tabs
                    Picker("Type", selection: $selectedTab) {
                        Text("Shifts (\(economyManager.availableShifts.count))").tag(0)
                        Text("Tasks (\(taskManager.openTasksCount))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.md) {
                            if selectedTab == 0 {
                                shiftsMarketplace
                            } else {
                                tasksMarketplace
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Opportunities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    var shiftsMarketplace: some View {
        Group {
            if economyManager.availableShifts.isEmpty {
                emptyState(
                    icon: "calendar.badge.checkmark",
                    title: "All shifts claimed!",
                    message: "Check back later or ask an admin about upcoming shifts."
                )
            } else {
                ForEach(economyManager.availableShifts) { shift in
                    OpportunityShiftCard(shift: shift)
                }
            }
        }
    }
    
    var tasksMarketplace: some View {
        Group {
            let openTasks = taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
            if openTasks.isEmpty {
                emptyState(
                    icon: "checkmark.circle",
                    title: "All tasks handled!",
                    message: "The camp is running smoothly. Check back later."
                )
            } else {
                ForEach(openTasks) { task in
                    OpportunityTaskCard(task: task)
                }
            }
        }
    }
    
    func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.connected)
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            Text(message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }
}

// MARK: - Opportunity Shift Card
struct OpportunityShiftCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    let shift: AnonymousShift
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: shift.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.turquoise)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.turquoise.opacity(0.15))
                    .cornerRadius(Theme.CornerRadius.md)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(formatDate(shift.startTime))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("+\(shift.totalPoints)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    Text("pts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            // Claim button
            Button(action: {
                economyManager.claimShift(shift)
            }) {
                Text("Claim This Shift")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.turquoise)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Opportunity Task Card
struct OpportunityTaskCard: View {
    @EnvironmentObject var taskManager: TaskManager
    let task: AdHocTask
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(task.priority.shortLabel)
                        Text("•")
                        Text(task.status.rawValue)
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("+\(task.pointsValue)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    Text("pts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            if let description = task.description {
                Text(description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    .lineLimit(2)
            }
            
            // Claim button
            Button(action: {
                taskManager.claimTask(task.id, memberName: "Me")
            }) {
                Text("I'll Do This")
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    var priorityColor: Color {
        switch task.priority {
        case .high: return Theme.Colors.emergency
        case .medium: return Theme.Colors.warning
        case .low: return Theme.Colors.turquoise
        }
    }
}

#Preview {
    ShiftsView()
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
        .environmentObject(EconomyManager())
        .environmentObject(DraftManager())
        .environmentObject(TaskManager())
}
