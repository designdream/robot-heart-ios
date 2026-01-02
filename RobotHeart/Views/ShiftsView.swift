import SwiftUI

struct ShiftsView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var draftManager: DraftManager
    @EnvironmentObject var taskManager: TaskManager
    @State private var showingAdminView = false
    @State private var showingAddTask = false
    @State private var selectedTab = 0  // 0 = Shifts, 1 = Tasks
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // POINTS CARD - Primary incentive at top (always visible)
                    ShiftPointsCard()
                        .padding(.horizontal)
                        .padding(.top)
                    
                    // Segmented control for Shifts vs Tasks
                    Picker("View", selection: $selectedTab) {
                        Text("Shifts").tag(0)
                        Text("Tasks (\(taskManager.openTasksCount))").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        shiftsContent
                    } else {
                        tasksContent
                    }
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
                    HStack(spacing: Theme.Spacing.sm) {
                        // Leaderboard
                        NavigationLink(destination: EconomyDashboardView()) {
                            Image(systemName: "chart.bar.fill")
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
            .onAppear {
                economyManager.refreshAvailableShifts()
            }
        }
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

#Preview {
    ShiftsView()
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
}
