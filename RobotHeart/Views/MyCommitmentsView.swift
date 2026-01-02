import SwiftUI

// MARK: - My Commitments View
/// Unified view showing all user commitments: shifts AND tasks together.
/// Designed to answer "What do I need to do?" at a glance.
///
/// Key UX improvements:
/// - Muted colors for unclaimed items, vibrant for MY commitments
/// - Timeline view sorted by date/time
/// - Clear visual distinction between shifts vs tasks
/// - Deadline indicators and urgency badges

struct MyCommitmentsView: View {
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var economyManager: EconomyManager
    
    @State private var viewMode: ViewMode = .myCommitments
    @State private var selectedDate: Date = Date()
    @State private var showingSwapSheet = false
    @State private var selectedCommitment: Commitment?
    
    enum ViewMode: String, CaseIterable {
        case myCommitments = "Mine"
        case calendar = "Calendar"
        case available = "Available"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // View mode picker
                    viewModePicker
                    
                    // Summary bar (only in My Commitments mode)
                    if viewMode == .myCommitments {
                        commitmentSummaryBar
                    }
                    
                    // Content
                    switch viewMode {
                    case .myCommitments:
                        myCommitmentsContent
                    case .calendar:
                        calendarContent
                    case .available:
                        availableContent
                    }
                }
            }
            .navigationTitle("Commitments")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingSwapSheet) {
            if let commitment = selectedCommitment {
                SwapRequestView(commitment: commitment)
            }
        }
    }
    
    // MARK: - View Mode Picker
    
    private var viewModePicker: some View {
        Picker("View", selection: $viewMode) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding()
    }
    
    // MARK: - Summary Bar
    
    private var commitmentSummaryBar: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Shifts count
            SummaryPill(
                icon: "clock.fill",
                count: myShifts.count,
                label: "Shifts",
                color: Theme.Colors.turquoise
            )
            
            // Tasks count
            SummaryPill(
                icon: "checklist",
                count: myTasks.count,
                label: "Tasks",
                color: Theme.Colors.goldenYellow
            )
            
            // Urgent count
            if urgentCount > 0 {
                SummaryPill(
                    icon: "exclamationmark.triangle.fill",
                    count: urgentCount,
                    label: "Urgent",
                    color: Theme.Colors.emergency
                )
            }
            
            // Social Capital (not "points" - this is about trust, not competition)
            SummaryPill(
                icon: "heart.circle.fill",
                count: totalCapital,
                label: "Capital",
                color: Theme.Colors.sunsetOrange
            )
        }
        .padding(.horizontal)
        .padding(.bottom, Theme.Spacing.sm)
    }
    
    // MARK: - My Commitments Content
    
    private var myCommitmentsContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                if allMyCommitments.isEmpty {
                    emptyStateView
                } else {
                    // Today's commitments
                    let todayItems = commitments(for: .today)
                    if !todayItems.isEmpty {
                        CommitmentSection(
                            title: "Today",
                            commitments: todayItems,
                            isMine: true,
                            onSwap: { commitment in
                                selectedCommitment = commitment
                                showingSwapSheet = true
                            }
                        )
                    }
                    
                    // Tomorrow
                    let tomorrowItems = commitments(for: .tomorrow)
                    if !tomorrowItems.isEmpty {
                        CommitmentSection(
                            title: "Tomorrow",
                            commitments: tomorrowItems,
                            isMine: true,
                            onSwap: { commitment in
                                selectedCommitment = commitment
                                showingSwapSheet = true
                            }
                        )
                    }
                    
                    // This week
                    let weekItems = commitments(for: .thisWeek)
                    if !weekItems.isEmpty {
                        CommitmentSection(
                            title: "This Week",
                            commitments: weekItems,
                            isMine: true,
                            onSwap: { commitment in
                                selectedCommitment = commitment
                                showingSwapSheet = true
                            }
                        )
                    }
                    
                    // Later
                    let laterItems = commitments(for: .later)
                    if !laterItems.isEmpty {
                        CommitmentSection(
                            title: "Later",
                            commitments: laterItems,
                            isMine: true,
                            onSwap: { commitment in
                                selectedCommitment = commitment
                                showingSwapSheet = true
                            }
                        )
                    }
                    
                    // Overdue tasks
                    let overdueItems = overdueCommitments
                    if !overdueItems.isEmpty {
                        CommitmentSection(
                            title: "⚠️ Overdue",
                            commitments: overdueItems,
                            isMine: true,
                            isUrgent: true,
                            onSwap: { _ in }
                        )
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Calendar Content
    
    private var calendarContent: some View {
        VStack(spacing: 0) {
            // Week navigation
            WeekNavigator(selectedDate: $selectedDate)
            
            // Week view with muted/highlighted colors
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    ForEach(weekDates, id: \.self) { date in
                        CalendarDayColumn(
                            date: date,
                            commitments: allCommitments(for: date),
                            myCommitmentIDs: Set(allMyCommitments.map { $0.id })
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Available Content
    
    private var availableContent: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                // Available shifts (muted)
                if !availableShifts.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("AVAILABLE SHIFTS")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        ForEach(availableShifts) { shift in
                            AvailableCommitmentRow(
                                commitment: Commitment.from(shift: shift),
                                onClaim: { claimShift(shift) }
                            )
                        }
                    }
                }
                
                // Open tasks (muted)
                if !openTasks.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("OPEN TASKS")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        ForEach(openTasks) { task in
                            AvailableCommitmentRow(
                                commitment: Commitment.from(task: task),
                                onClaim: { claimTask(task) }
                            )
                        }
                    }
                }
                
                if availableShifts.isEmpty && openTasks.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.Colors.connected.opacity(0.5))
                        
                        Text("All Caught Up!")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text("No open shifts or tasks available")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                    .padding(.top, 100)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Commitments Yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Claim shifts or tasks to see them here")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            
            Button(action: { viewMode = .available }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Browse Available")
                }
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(.top, 100)
    }
    
    // MARK: - Computed Properties
    
    private var myShifts: [ShiftBlock] {
        shiftBlockManager.myUpcomingShifts
    }
    
    private var myTasks: [AdHocTask] {
        taskManager.myTasks
    }
    
    private var allMyCommitments: [Commitment] {
        var commitments: [Commitment] = []
        
        // Add shifts
        for block in myShifts {
            commitments.append(Commitment.from(shiftBlock: block))
        }
        
        // Add tasks
        for task in myTasks {
            commitments.append(Commitment.from(task: task))
        }
        
        // Sort by date
        return commitments.sorted { $0.dateTime < $1.dateTime }
    }
    
    private var urgentCount: Int {
        let urgentTasks = myTasks.filter { $0.priority == .high || $0.isOverdue }
        let urgentShifts = myShifts.filter { $0.startTime < Date().addingTimeInterval(3600) }
        return urgentTasks.count + urgentShifts.count
    }
    
    private var totalCapital: Int {
        let shiftCapital = shiftBlockManager.myTotalPoints
        let taskCapital = myTasks.reduce(0) { $0 + $1.priority.points }
        return shiftCapital + taskCapital
    }
    
    private var availableShifts: [AnonymousShift] {
        economyManager.availableShifts
    }
    
    private var openTasks: [AdHocTask] {
        taskManager.tasks.filter { $0.status == .open && $0.assignedTo == nil }
    }
    
    private var overdueCommitments: [Commitment] {
        allMyCommitments.filter { $0.isOverdue }
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    // MARK: - Time Period Filtering
    
    enum TimePeriod {
        case today, tomorrow, thisWeek, later
    }
    
    private func commitments(for period: TimePeriod) -> [Commitment] {
        let calendar = Calendar.current
        let now = Date()
        
        return allMyCommitments.filter { commitment in
            guard !commitment.isOverdue else { return false }
            
            switch period {
            case .today:
                return calendar.isDateInToday(commitment.dateTime)
            case .tomorrow:
                return calendar.isDateInTomorrow(commitment.dateTime)
            case .thisWeek:
                let startOfToday = calendar.startOfDay(for: now)
                let twoDaysFromNow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
                return commitment.dateTime >= twoDaysFromNow && commitment.dateTime < endOfWeek
            case .later:
                let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
                return commitment.dateTime >= endOfWeek
            }
        }
    }
    
    private func allCommitments(for date: Date) -> [Commitment] {
        let calendar = Calendar.current
        var commitments: [Commitment] = []
        
        // Shifts for this date
        for block in shiftBlockManager.blocksForDate(date) {
            commitments.append(Commitment.from(shiftBlock: block))
        }
        
        // Tasks with due date on this date
        for task in taskManager.tasks {
            if let dueDate = task.dueDate, calendar.isDate(dueDate, inSameDayAs: date) {
                commitments.append(Commitment.from(task: task))
            }
        }
        
        return commitments.sorted { $0.dateTime < $1.dateTime }
    }
    
    // MARK: - Actions
    
    private func claimShift(_ shift: AnonymousShift) {
        _ = economyManager.claimShift(shift)
    }
    
    private func claimTask(_ task: AdHocTask) {
        taskManager.claimTask(task.id, memberName: "Me")
    }
}

// MARK: - Commitment Model (Unified)

struct Commitment: Identifiable {
    let id: String
    let type: CommitmentType
    let title: String
    let subtitle: String
    let dateTime: Date
    let endTime: Date?
    let location: String?
    let capital: Int
    let priority: Priority
    let isMine: Bool
    let isOverdue: Bool
    
    enum CommitmentType {
        case shift
        case task
        
        var icon: String {
            switch self {
            case .shift: return "clock.fill"
            case .task: return "checklist"
            }
        }
        
        var color: Color {
            switch self {
            case .shift: return Theme.Colors.turquoise
            case .task: return Theme.Colors.goldenYellow
            }
        }
    }
    
    enum Priority {
        case urgent, high, normal, low
        
        var color: Color {
            switch self {
            case .urgent: return Theme.Colors.emergency
            case .high: return Theme.Colors.warning
            case .normal: return Theme.Colors.robotCream
            case .low: return Theme.Colors.robotCream.opacity(0.5)
            }
        }
    }
    
    static func from(shiftBlock: ShiftBlock) -> Commitment {
        let currentUserID = UserDefaults.standard.string(forKey: "userID") ?? "!local"
        let isMine = shiftBlock.hasMember(currentUserID)
        let mySlots = shiftBlock.slots.filter { $0.assignedTo == currentUserID }
        let capital = mySlots.reduce(0) { $0 + $1.pointValue }
        
        return Commitment(
            id: shiftBlock.id.uuidString,
            type: .shift,
            title: shiftBlock.location.rawValue,
            subtitle: formatTimeRange(shiftBlock.startTime, shiftBlock.endTime),
            dateTime: shiftBlock.startTime,
            endTime: shiftBlock.endTime,
            location: shiftBlock.location.rawValue,
            capital: capital,
            priority: shiftBlock.startTime < Date().addingTimeInterval(3600) ? .urgent : .normal,
            isMine: isMine,
            isOverdue: shiftBlock.endTime < Date()
        )
    }
    
    static func from(task: AdHocTask) -> Commitment {
        let currentUserID = UserDefaults.standard.string(forKey: "userID") ?? "!local"
        let isMine = task.assignedTo == currentUserID
        
        let priority: Priority
        switch task.priority {
        case .high: priority = task.isOverdue ? .urgent : .high
        case .medium: priority = .normal
        case .low: priority = .low
        }
        
        return Commitment(
            id: task.id.uuidString,
            type: .task,
            title: task.title,
            subtitle: task.dueDate.map { "Due: \(formatDate($0))" } ?? "No deadline",
            dateTime: task.dueDate ?? task.createdAt,
            endTime: nil,
            location: nil,
            capital: task.priority.points,
            priority: priority,
            isMine: isMine,
            isOverdue: task.isOverdue
        )
    }
    
    static func from(shift: AnonymousShift) -> Commitment {
        Commitment(
            id: shift.id.uuidString,
            type: .shift,
            title: shift.location.rawValue,
            subtitle: formatTimeRange(shift.startTime, shift.endTime),
            dateTime: shift.startTime,
            endTime: shift.endTime,
            location: shift.location.rawValue,
            capital: shift.totalPoints,
            priority: shift.isUrgent ? .high : .normal,
            isMine: false,
            isOverdue: false
        )
    }
    
    private static func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Summary Pill

struct SummaryPill: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Commitment Section

struct CommitmentSection: View {
    let title: String
    let commitments: [Commitment]
    let isMine: Bool
    var isUrgent: Bool = false
    let onSwap: (Commitment) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title.uppercased())
                .font(Theme.Typography.caption)
                .foregroundColor(isUrgent ? Theme.Colors.emergency : Theme.Colors.robotCream.opacity(0.5))
            
            ForEach(commitments) { commitment in
                CommitmentRow(
                    commitment: commitment,
                    isMine: isMine,
                    onSwap: { onSwap(commitment) }
                )
            }
        }
    }
}

// MARK: - Commitment Row (My Commitments - Highlighted)

struct CommitmentRow: View {
    let commitment: Commitment
    let isMine: Bool
    let onSwap: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Type indicator
            ZStack {
                Circle()
                    .fill(commitment.type.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: commitment.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(commitment.type.color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(commitment.title)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if commitment.priority == .urgent || commitment.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(commitment.priority.color)
                    }
                }
                
                Text(commitment.subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            // Social Capital badge
            if commitment.capital > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                    Text("+\(commitment.capital)")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(Theme.Colors.sunsetOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.Colors.sunsetOrange.opacity(0.2))
                .cornerRadius(Theme.CornerRadius.sm)
            }
            
            // Swap button (for shifts)
            if commitment.type == .shift && isMine {
                Button(action: onSwap) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(commitment.isOverdue ? Theme.Colors.emergency : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Available Commitment Row (Muted)

struct AvailableCommitmentRow: View {
    let commitment: Commitment
    let onClaim: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Type indicator (muted)
            ZStack {
                Circle()
                    .fill(Theme.Colors.robotCream.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: commitment.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            // Content (muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(commitment.title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                
                Text(commitment.subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            Spacer()
            
            // Claim button
            Button(action: onClaim) {
                HStack(spacing: 4) {
                    Text("+\(commitment.capital)")
                        .font(.system(size: 12, weight: .bold))
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                }
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight.opacity(0.5))
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Week Navigator

struct WeekNavigator: View {
    @Binding var selectedDate: Date
    
    var body: some View {
        HStack {
            Button(action: { navigateWeek(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            Spacer()
            
            Text(weekText)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
            
            Button(action: { navigateWeek(1) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
    
    private var weekText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "'Week of' MMM d"
        return formatter.string(from: selectedDate)
    }
    
    private func navigateWeek(_ direction: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: direction * 7, to: selectedDate) ?? selectedDate
    }
}

// MARK: - Calendar Day Column

struct CalendarDayColumn: View {
    let date: Date
    let commitments: [Commitment]
    let myCommitmentIDs: Set<String>
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Day header
            VStack(spacing: 2) {
                Text(dayName)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                
                Text(dayNumber)
                    .font(Theme.Typography.headline)
                    .foregroundColor(isToday ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
            }
            .padding(.vertical, Theme.Spacing.sm)
            .frame(width: 90)
            .background(isToday ? Theme.Colors.sunsetOrange.opacity(0.2) : Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.sm)
            
            // Commitments
            ForEach(commitments) { commitment in
                CalendarCommitmentCard(
                    commitment: commitment,
                    isMine: myCommitmentIDs.contains(commitment.id)
                )
            }
            
            Spacer()
        }
        .frame(width: 90)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Calendar Commitment Card (Muted vs Highlighted)

struct CalendarCommitmentCard: View {
    let commitment: Commitment
    let isMine: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: commitment.type.icon)
                .font(.title3)
                .foregroundColor(isMine ? commitment.type.color : Theme.Colors.robotCream.opacity(0.3))
            
            Text(timeText)
                .font(.system(size: 10))
                .foregroundColor(isMine ? Theme.Colors.robotCream.opacity(0.8) : Theme.Colors.robotCream.opacity(0.3))
            
            if isMine {
                Text("+\(commitment.capital)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(width: 90)
        .background(isMine ? Theme.Colors.backgroundMedium : Theme.Colors.backgroundLight.opacity(0.3))
        .cornerRadius(Theme.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(isMine ? commitment.type.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: commitment.dateTime)
    }
}

// MARK: - Swap Request View (Placeholder)

struct SwapRequestView: View {
    let commitment: Commitment
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 50))
                        .foregroundColor(Theme.Colors.turquoise)
                    
                    Text("Request Swap")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Looking for someone to swap \(commitment.title) shift")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        .multilineTextAlignment(.center)
                    
                    // TODO: Implement swap matching
                    Text("Coming soon...")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                }
                .padding()
            }
            .navigationTitle("Swap Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MyCommitmentsView()
        .environmentObject(ShiftBlockManager())
        .environmentObject(ShiftManager())
        .environmentObject(TaskManager())
        .environmentObject(EconomyManager())
}
