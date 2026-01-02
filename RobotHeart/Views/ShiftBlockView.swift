import SwiftUI

// MARK: - Shift Block Hub View
struct ShiftBlockHubView: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    @EnvironmentObject var shiftManager: ShiftManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // View mode toggle
                    ViewModeToggle(viewMode: $blockManager.viewMode)
                    
                    // Date navigation
                    DateNavigator(selectedDate: $blockManager.selectedDate, viewMode: blockManager.viewMode)
                    
                    // Content
                    if blockManager.viewMode == .day {
                        DayShiftView()
                    } else {
                        WeekShiftView()
                    }
                }
            }
            .navigationTitle("Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if shiftManager.isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: CreateShiftBlockView()) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - View Mode Toggle
struct ViewModeToggle: View {
    @Binding var viewMode: ShiftBlockManager.ViewMode
    
    var body: some View {
        Picker("View", selection: $viewMode) {
            Text("Day").tag(ShiftBlockManager.ViewMode.day)
            Text("Week").tag(ShiftBlockManager.ViewMode.week)
        }
        .pickerStyle(.segmented)
        .padding()
    }
}

// MARK: - Date Navigator
struct DateNavigator: View {
    @Binding var selectedDate: Date
    let viewMode: ShiftBlockManager.ViewMode
    
    var body: some View {
        HStack {
            Button(action: { navigatePrevious() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            Spacer()
            
            Text(dateText)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
            
            Button(action: { navigateNext() }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.backgroundMedium)
    }
    
    private var dateText: String {
        let formatter = DateFormatter()
        if viewMode == .day {
            formatter.dateFormat = "EEEE, MMM d"
        } else {
            formatter.dateFormat = "'Week of' MMM d"
        }
        return formatter.string(from: selectedDate)
    }
    
    private func navigatePrevious() {
        let days = viewMode == .day ? -1 : -7
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }
    
    private func navigateNext() {
        let days = viewMode == .day ? 1 : 7
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }
}

// MARK: - Day Shift View
struct DayShiftView: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                if blockManager.blocksForSelectedDate.isEmpty {
                    EmptyShiftDayView()
                } else {
                    ForEach(blockManager.blocksForSelectedDate) { block in
                        NavigationLink(destination: ShiftBlockDetailView(block: block)) {
                            ShiftBlockCard(block: block)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Week Shift View
struct WeekShiftView: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                ForEach(blockManager.weekDates, id: \.self) { date in
                    WeekDayColumn(date: date)
                }
            }
            .padding()
        }
    }
}

// MARK: - Week Day Column
struct WeekDayColumn: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    let date: Date
    
    var blocks: [ShiftBlock] {
        blockManager.blocksForDate(date)
    }
    
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
            .frame(width: 100)
            .background(isToday ? Theme.Colors.sunsetOrange.opacity(0.2) : Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.sm)
            
            // Blocks
            ForEach(blocks) { block in
                NavigationLink(destination: ShiftBlockDetailView(block: block)) {
                    WeekBlockCard(block: block)
                }
            }
            
            Spacer()
        }
        .frame(width: 100)
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

// MARK: - Week Block Card (compact)
struct WeekBlockCard: View {
    let block: ShiftBlock
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: block.location.icon)
                .font(.title3)
                .foregroundColor(Theme.Colors.turquoise)
            
            Text(timeText)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            
            // Fill indicator
            HStack(spacing: 2) {
                Text("\(block.filledSlots)/\(block.totalSlots)")
                    .font(.system(size: 10, weight: .bold))
                
                Circle()
                    .fill(fillColor)
                    .frame(width: 6, height: 6)
            }
            .foregroundColor(Theme.Colors.robotCream)
        }
        .padding(Theme.Spacing.sm)
        .frame(width: 100)
        .background(block.isReleased ? Theme.Colors.backgroundMedium : Theme.Colors.backgroundLight.opacity(0.5))
        .cornerRadius(Theme.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.sm)
                .stroke(block.isReleased ? Color.clear : Theme.Colors.warning.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        return formatter.string(from: block.startTime)
    }
    
    private var fillColor: Color {
        if block.isFull { return Theme.Colors.connected }
        if block.fillPercentage > 0.5 { return Theme.Colors.warning }
        return Theme.Colors.disconnected
    }
}

// MARK: - Shift Block Card (full)
struct ShiftBlockCard: View {
    let block: ShiftBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: block.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.turquoise)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(block.timeRangeText)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                // Status badge
                if !block.isReleased {
                    Text("Unreleased")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.warning)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.warning.opacity(0.2))
                        .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            
            // Slots summary
            HStack(spacing: Theme.Spacing.md) {
                // Fill progress
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Theme.Colors.backgroundLight)
                                .frame(height: 6)
                            
                            Rectangle()
                                .fill(fillColor)
                                .frame(width: geometry.size.width * block.fillPercentage, height: 6)
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 6)
                    
                    Text("\(block.filledSlots)/\(block.totalSlots) positions filled")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                // Points
                VStack(alignment: .trailing) {
                    Text("+\(block.totalPoints)")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    
                    Text("total pts")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            // Job type pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(block.slots) { slot in
                        JobTypePill(slot: slot)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var fillColor: Color {
        if block.isFull { return Theme.Colors.connected }
        if block.fillPercentage > 0.5 { return Theme.Colors.warning }
        return Theme.Colors.turquoise
    }
}

// MARK: - Job Type Pill
struct JobTypePill: View {
    let slot: ShiftSlot
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: slot.jobType.icon)
                .font(.caption2)
            
            if let name = slot.assignedName {
                Text(name)
                    .font(.system(size: 10))
            }
        }
        .foregroundColor(slot.isAvailable ? Theme.Colors.robotCream.opacity(0.6) : Theme.Colors.robotCream)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 4)
        .background(slot.isAvailable ? Theme.Colors.backgroundLight : categoryColor.opacity(0.3))
        .cornerRadius(Theme.CornerRadius.full)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.full)
                .stroke(slot.isAvailable ? Theme.Colors.backgroundLight : categoryColor, lineWidth: 1)
        )
    }
    
    private var categoryColor: Color {
        switch slot.jobType.category {
        case .bus: return Theme.Colors.sunsetOrange
        case .campLife: return Theme.Colors.turquoise
        case .infrastructure: return Theme.Colors.goldenYellow
        case .operations: return Theme.Colors.dustyPink
        }
    }
}

// MARK: - Shift Block Detail View
struct ShiftBlockDetailView: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    @EnvironmentObject var shiftManager: ShiftManager
    let block: ShiftBlock
    
    @State private var showingClaimAlert = false
    @State private var alertMessage = ""
    @State private var selectedSlot: ShiftSlot?
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    BlockDetailHeader(block: block)
                    
                    // Assigned members (if released)
                    if block.isReleased && !block.assignedMembers.isEmpty {
                        AssignedMembersSection(block: block)
                    }
                    
                    // Available slots
                    AvailableSlotsSection(
                        block: block,
                        onClaimSlot: { slot in
                            claimSlot(slot)
                        }
                    )
                    
                    // Admin controls
                    if shiftManager.isAdmin {
                        AdminControlsSection(block: block)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(block.location.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Shift Claim", isPresented: $showingClaimAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func claimSlot(_ slot: ShiftSlot) {
        let result = blockManager.claimSlot(blockID: block.id, slotID: slot.id)
        alertMessage = result.message
        showingClaimAlert = true
    }
}

// MARK: - Block Detail Header
struct BlockDetailHeader: View {
    let block: ShiftBlock
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: block.location.icon)
                    .font(.largeTitle)
                    .foregroundColor(Theme.Colors.turquoise)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(block.dayText)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(block.timeRangeText)
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
                
                Spacer()
            }
            
            // Stats
            HStack(spacing: Theme.Spacing.xl) {
                StatItem(value: "\(block.openSlots)", label: "Open", color: Theme.Colors.connected)
                StatItem(value: "\(block.filledSlots)", label: "Filled", color: Theme.Colors.turquoise)
                StatItem(value: "+\(block.totalPoints)", label: "Points", color: Theme.Colors.sunsetOrange)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
    }
}

// MARK: - Assigned Members Section
struct AssignedMembersSection: View {
    let block: ShiftBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Crew")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            ForEach(block.assignedMembers, id: \.name) { member in
                HStack {
                    Image(systemName: member.job.icon)
                        .foregroundColor(categoryColor(for: member.job))
                    
                    Text(member.name)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Spacer()
                    
                    Text(member.job.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func categoryColor(for job: ShiftJobType) -> Color {
        switch job.category {
        case .bus: return Theme.Colors.sunsetOrange
        case .campLife: return Theme.Colors.turquoise
        case .infrastructure: return Theme.Colors.goldenYellow
        case .operations: return Theme.Colors.dustyPink
        }
    }
}

// MARK: - Available Slots Section
struct AvailableSlotsSection: View {
    let block: ShiftBlock
    let onClaimSlot: (ShiftSlot) -> Void
    
    var openSlots: [ShiftSlot] {
        block.slots.filter { $0.isAvailable }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Available Positions")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            if !block.isReleased {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("This shift hasn't been released yet")
                }
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.warning)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Theme.Colors.warning.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.md)
            } else if openSlots.isEmpty {
                Text("All positions are filled")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .padding()
            } else {
                ForEach(openSlots) { slot in
                    SlotClaimRow(slot: slot, onClaim: { onClaimSlot(slot) })
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Slot Claim Row
struct SlotClaimRow: View {
    let slot: ShiftSlot
    let onClaim: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: slot.jobType.icon)
                .font(.title3)
                .foregroundColor(categoryColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(slot.jobType.rawValue)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text(slot.jobType.category.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Spacer()
            
            Text("+\(slot.pointValue)")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.sunsetOrange)
            
            Button(action: onClaim) {
                Text("Claim")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Colors.connected)
                    .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private var categoryColor: Color {
        switch slot.jobType.category {
        case .bus: return Theme.Colors.sunsetOrange
        case .campLife: return Theme.Colors.turquoise
        case .infrastructure: return Theme.Colors.goldenYellow
        case .operations: return Theme.Colors.dustyPink
        }
    }
}

// MARK: - Admin Controls Section
struct AdminControlsSection: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    let block: ShiftBlock
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Admin Controls")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            if !block.isReleased {
                Button(action: {
                    blockManager.releaseBlock(block.id)
                }) {
                    HStack {
                        Image(systemName: "lock.open.fill")
                        Text("Release Shift")
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            } else {
                Text("Shift released \(formatDate(block.releasedAt))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.connected)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Create Shift Block View (Admin)
struct CreateShiftBlockView: View {
    @EnvironmentObject var blockManager: ShiftBlockManager
    @Environment(\.dismiss) var dismiss
    
    @State private var location: Shift.ShiftLocation = .bus
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(4 * 3600)
    @State private var selectedTemplate: ShiftBlockManager.ShiftBlockTemplate = .bus
    @State private var useTemplate = true
    @State private var customSlots: [ShiftJobType] = []
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            Form {
                Section {
                    Picker("Location", selection: $location) {
                        ForEach(Shift.ShiftLocation.allCases, id: \.self) { loc in
                            Text(loc.rawValue).tag(loc)
                        }
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                    
                    DatePicker("Start", selection: $startTime)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    DatePicker("End", selection: $endTime)
                        .foregroundColor(Theme.Colors.robotCream)
                } header: {
                    Text("Shift Details")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Section {
                    Toggle("Use Template", isOn: $useTemplate)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                    
                    if useTemplate {
                        Picker("Template", selection: $selectedTemplate) {
                            Text("Bus (8 positions)").tag(ShiftBlockManager.ShiftBlockTemplate.bus)
                            Text("Camp (6 positions)").tag(ShiftBlockManager.ShiftBlockTemplate.camp)
                            Text("Infrastructure (5 positions)").tag(ShiftBlockManager.ShiftBlockTemplate.infrastructure)
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    }
                } header: {
                    Text("Positions")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Create Shift")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    createBlock()
                }
                .foregroundColor(Theme.Colors.sunsetOrange)
            }
        }
    }
    
    private func createBlock() {
        if useTemplate {
            _ = blockManager.createFromTemplate(selectedTemplate, startTime: startTime, endTime: endTime)
        } else {
            let slots = customSlots.map { ShiftSlot(jobType: $0) }
            _ = blockManager.createBlock(location: location, startTime: startTime, endTime: endTime, slots: slots)
        }
        dismiss()
    }
}

// MARK: - Empty Day View (Shift Block)
struct EmptyShiftDayView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "calendar")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Shifts This Day")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Check another day or wait for shifts to be released")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    ShiftBlockHubView()
        .environmentObject(ShiftBlockManager())
        .environmentObject(ShiftManager())
}
