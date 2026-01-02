import SwiftUI

// MARK: - Draft Hub View
struct DraftHubView: View {
    @EnvironmentObject var draftManager: DraftManager
    @EnvironmentObject var shiftManager: ShiftManager
    @State private var showingCreateDraft = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Active draft banner
                        if let activeDraft = draftManager.activeDraft {
                            ActiveDraftBanner(draft: activeDraft)
                        }
                        
                        // Upcoming drafts
                        if !draftManager.upcomingDrafts.isEmpty {
                            DraftSection(title: "Upcoming Drafts", drafts: draftManager.upcomingDrafts)
                        }
                        
                        // Completed drafts
                        if !draftManager.completedDrafts.isEmpty {
                            DraftSection(title: "Past Drafts", drafts: draftManager.completedDrafts)
                        }
                        
                        // Empty state
                        if draftManager.upcomingDrafts.isEmpty && draftManager.completedDrafts.isEmpty && draftManager.activeDraft == nil {
                            EmptyDraftView()
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Shift Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if shiftManager.isAdmin {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateDraft = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateDraft) {
                CreateDraftView()
            }
        }
    }
}

// MARK: - Active Draft Banner
struct ActiveDraftBanner: View {
    @EnvironmentObject var draftManager: DraftManager
    let draft: ShiftDraft
    
    var body: some View {
        NavigationLink(destination: LiveDraftView(draft: draft)) {
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(Theme.Colors.connected)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(draft.name)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text("LIVE NOW")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.connected)
                    }
                    
                    Spacer()
                    
                    if draftManager.isMyTurn {
                        Text("YOUR PICK!")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(Theme.Colors.sunsetOrange)
                            .cornerRadius(Theme.CornerRadius.full)
                    }
                }
                
                // Timer
                if draftManager.isMyTurn {
                    HStack {
                        Image(systemName: "timer")
                        Text("\(Int(draftManager.pickTimer))s remaining")
                            .font(Theme.Typography.headline)
                    }
                    .foregroundColor(draftManager.pickTimer < 10 ? Theme.Colors.emergency : Theme.Colors.warning)
                }
                
                // Progress
                HStack {
                    Text("Round \(draft.currentRound)/\(draft.totalRounds)")
                    Spacer()
                    Text("\(draft.picksMade)/\(draft.totalPicks) picks")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                    .stroke(draftManager.isMyTurn ? Theme.Colors.sunsetOrange : Theme.Colors.connected, lineWidth: 2)
            )
        }
    }
}

// MARK: - Draft Section
struct DraftSection: View {
    let title: String
    let drafts: [ShiftDraft]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            ForEach(drafts) { draft in
                NavigationLink(destination: DraftDetailView(draft: draft)) {
                    DraftCard(draft: draft)
                }
            }
        }
    }
}

// MARK: - Draft Card
struct DraftCard: View {
    let draft: ShiftDraft
    
    var body: some View {
        HStack {
            Image(systemName: draft.status.icon)
                .font(.title2)
                .foregroundColor(statusColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(draft.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("\(draft.availableShifts.count) shifts • \(draft.pickOrder.count) participants")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            if let scheduled = draft.scheduledStart {
                Text(formatDate(scheduled))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var statusColor: Color {
        switch draft.status {
        case .setup: return Theme.Colors.warning
        case .scheduled: return Theme.Colors.turquoise
        case .active: return Theme.Colors.connected
        case .paused: return Theme.Colors.warning
        case .completed: return Theme.Colors.robotCream.opacity(0.5)
        case .cancelled: return Theme.Colors.disconnected
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Live Draft View
struct LiveDraftView: View {
    @EnvironmentObject var draftManager: DraftManager
    let draft: ShiftDraft
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with timer
                DraftHeader(draft: draft)
                
                // Available shifts
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(draft.remainingShifts) { shift in
                            DraftableShiftCard(
                                shift: shift,
                                isPickable: draftManager.isMyTurn,
                                onPick: {
                                    draftManager.makePick(shiftID: shift.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // My picks summary
                MyPicksSummary(draft: draft)
            }
        }
        .navigationTitle(draft.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Draft Header
struct DraftHeader: View {
    @EnvironmentObject var draftManager: DraftManager
    let draft: ShiftDraft
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // Current picker
            HStack {
                if draftManager.isMyTurn {
                    Text("YOUR TURN TO PICK!")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                } else {
                    Text("Waiting for pick...")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                // Timer
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.backgroundLight, lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: draftManager.pickTimer / draft.settings.secondsPerPick)
                        .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(draftManager.pickTimer))")
                        .font(Theme.Typography.headline)
                        .foregroundColor(timerColor)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.Colors.backgroundLight)
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Theme.Colors.sunsetOrange)
                        .frame(width: geometry.size.width * (Double(draft.picksMade) / Double(max(1, draft.totalPicks))), height: 4)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
            
            HStack {
                Text("Round \(draft.currentRound) of \(draft.totalRounds)")
                Spacer()
                Text("\(draft.remainingShifts.count) shifts remaining")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
    
    private var timerColor: Color {
        if draftManager.pickTimer < 10 { return Theme.Colors.emergency }
        if draftManager.pickTimer < 20 { return Theme.Colors.warning }
        return Theme.Colors.connected
    }
}

// MARK: - Draftable Shift Card
struct DraftableShiftCard: View {
    let shift: DraftableShift
    let isPickable: Bool
    let onPick: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: shift.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.turquoise)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(shift.timeText)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(shift.pointValue)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    
                    DifficultyBadge(difficulty: shift.difficulty)
                }
            }
            
            HStack {
                Text(shift.durationText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                if let desc = shift.description {
                    Text("• \(desc)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            
            if isPickable {
                Button(action: onPick) {
                    Text("PICK THIS SHIFT")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(isPickable ? Theme.Colors.sunsetOrange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Difficulty Badge
struct DifficultyBadge: View {
    let difficulty: DraftableShift.Difficulty
    
    var body: some View {
        Text(difficulty.rawValue)
            .font(Theme.Typography.caption)
            .foregroundColor(difficultyColor)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, 2)
            .background(difficultyColor.opacity(0.2))
            .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return Theme.Colors.connected
        case .medium: return Theme.Colors.turquoise
        case .hard: return Theme.Colors.sunsetOrange
        case .expert: return Theme.Colors.emergency
        }
    }
}

// MARK: - My Picks Summary
struct MyPicksSummary: View {
    @EnvironmentObject var draftManager: DraftManager
    let draft: ShiftDraft
    
    var myPicks: [DraftableShift] {
        draftManager.myPicksInDraft(draft.id)
    }
    
    var myPoints: Int {
        draftManager.myPointsInDraft(draft.id)
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Text("Your Picks")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text("\(myPoints) pts")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            if myPicks.isEmpty {
                Text("No picks yet")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(myPicks) { shift in
                            VStack(spacing: 2) {
                                Image(systemName: shift.location.icon)
                                    .foregroundColor(Theme.Colors.turquoise)
                                Text("+\(shift.pointValue)")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.backgroundLight)
                            .cornerRadius(Theme.CornerRadius.sm)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Create Draft View (Admin)
struct CreateDraftView: View {
    @EnvironmentObject var draftManager: DraftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    @State private var draftName = ""
    @State private var scheduledDate = Date().addingTimeInterval(3600)
    @State private var roundsPerPerson = 3
    @State private var secondsPerPick = 60
    @State private var selectedParticipants: Set<String> = []
    @State private var shiftsToAdd: [DraftableShift] = []
    @State private var showingAddShift = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Draft Name", text: $draftName)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        DatePicker("Start Time", selection: $scheduledDate)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Details")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        Stepper("Rounds: \(roundsPerPerson)", value: $roundsPerPerson, in: 1...10)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Stepper("Seconds per pick: \(secondsPerPick)", value: $secondsPerPick, in: 30...180, step: 15)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Settings")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        ForEach(meshtasticManager.campMembers) { member in
                            Toggle(member.name, isOn: Binding(
                                get: { selectedParticipants.contains(member.id) },
                                set: { isSelected in
                                    if isSelected {
                                        selectedParticipants.insert(member.id)
                                    } else {
                                        selectedParticipants.remove(member.id)
                                    }
                                }
                            ))
                            .foregroundColor(Theme.Colors.robotCream)
                            .tint(Theme.Colors.sunsetOrange)
                        }
                    } header: {
                        Text("Participants (\(selectedParticipants.count))")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        ForEach(shiftsToAdd) { shift in
                            HStack {
                                Image(systemName: shift.location.icon)
                                    .foregroundColor(Theme.Colors.turquoise)
                                Text(shift.location.rawValue)
                                    .foregroundColor(Theme.Colors.robotCream)
                                Spacer()
                                Text("+\(shift.pointValue)")
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                        .onDelete { indexSet in
                            shiftsToAdd.remove(atOffsets: indexSet)
                        }
                        
                        Button(action: { showingAddShift = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Shift")
                            }
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    } header: {
                        Text("Shifts (\(shiftsToAdd.count))")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Create Draft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createDraft()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(draftName.isEmpty || selectedParticipants.isEmpty || shiftsToAdd.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddShift) {
                AddDraftShiftView(onAdd: { shift in
                    shiftsToAdd.append(shift)
                })
            }
        }
    }
    
    private func createDraft() {
        let settings = DraftSettings(
            roundsPerParticipant: roundsPerPerson,
            secondsPerPick: TimeInterval(secondsPerPick)
        )
        
        var draft = draftManager.createDraft(
            name: draftName,
            scheduledStart: scheduledDate,
            settings: settings
        )
        
        draftManager.setParticipants(draft.id, memberIDs: Array(selectedParticipants))
        draftManager.addShiftsToDraft(draft.id, shifts: shiftsToAdd)
        
        dismiss()
    }
}

// MARK: - Add Draft Shift View
struct AddDraftShiftView: View {
    let onAdd: (DraftableShift) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var location: Shift.ShiftLocation = .bus
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(7200)
    @State private var difficulty: DraftableShift.Difficulty = .medium
    @State private var description = ""
    
    var body: some View {
        NavigationView {
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
                        
                        Picker("Difficulty", selection: $difficulty) {
                            ForEach(DraftableShift.Difficulty.allCases, id: \.self) { d in
                                Text(d.rawValue).tag(d)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        TextField("Description (optional)", text: $description)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let shift = DraftableShift(
                            location: location,
                            startTime: startTime,
                            endTime: endTime,
                            description: description.isEmpty ? nil : description,
                            difficulty: difficulty,
                            createdBy: "!local"
                        )
                        onAdd(shift)
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

// MARK: - Draft Detail View
struct DraftDetailView: View {
    let draft: ShiftDraft
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    // Status
                    HStack {
                        Image(systemName: draft.status.icon)
                        Text(draft.status.rawValue)
                    }
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                    
                    // Stats
                    HStack(spacing: Theme.Spacing.xl) {
                        StatBox(value: "\(draft.availableShifts.count)", label: "Shifts")
                        StatBox(value: "\(draft.pickOrder.count)", label: "Participants")
                        StatBox(value: "\(draft.totalRounds)", label: "Rounds")
                    }
                    
                    // Shifts list
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Shifts")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        ForEach(draft.availableShifts) { shift in
                            HStack {
                                Image(systemName: shift.location.icon)
                                    .foregroundColor(Theme.Colors.turquoise)
                                Text(shift.location.rawValue)
                                    .foregroundColor(Theme.Colors.robotCream)
                                Spacer()
                                Text("+\(shift.pointValue)")
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                            .padding()
                            .background(Theme.Colors.backgroundMedium)
                            .cornerRadius(Theme.CornerRadius.sm)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle(draft.name)
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.Colors.sunsetOrange)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
    }
}

// MARK: - Empty Draft View
struct EmptyDraftView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "sportscourt")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Drafts Yet")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Admins can create a shift draft for the camp")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    DraftHubView()
        .environmentObject(DraftManager())
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
}
