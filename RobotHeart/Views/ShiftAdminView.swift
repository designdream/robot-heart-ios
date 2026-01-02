import SwiftUI

struct ShiftAdminView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedDate = Date()
    @State private var selectedLocation: Shift.ShiftLocation?
    @State private var showingAddShift = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Location filter
                    LocationFilterBar(selectedLocation: $selectedLocation)
                    
                    // Date picker
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .accentColor(Theme.Colors.sunsetOrange)
                    .padding(.horizontal)
                    .background(Theme.Colors.backgroundMedium)
                    
                    // Shifts for selected date
                    ScrollView {
                        VStack(spacing: Theme.Spacing.md) {
                            let dayShifts = filteredShifts
                            
                            if dayShifts.isEmpty {
                                EmptyDayView(date: selectedDate)
                            } else {
                                ForEach(dayShifts) { shift in
                                    AdminShiftRow(shift: shift) {
                                        shiftManager.deleteShift(shift)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Manage Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddShift = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            .sheet(isPresented: $showingAddShift) {
                CreateShiftView(initialDate: selectedDate)
                    .environmentObject(shiftManager)
                    .environmentObject(meshtasticManager)
            }
        }
    }
    
    private var filteredShifts: [Shift] {
        var shifts = shiftManager.shiftsForDate(selectedDate)
        if let location = selectedLocation {
            shifts = shifts.filter { $0.location == location }
        }
        return shifts.sorted { $0.startTime < $1.startTime }
    }
}

// MARK: - Location Filter Bar
struct LocationFilterBar: View {
    @Binding var selectedLocation: Shift.ShiftLocation?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    title: "All",
                    isSelected: selectedLocation == nil,
                    action: { selectedLocation = nil }
                )
                
                ForEach(Shift.ShiftLocation.allCases, id: \.self) { location in
                    FilterChip(
                        title: location.rawValue,
                        icon: location.icon,
                        isSelected: selectedLocation == location,
                        action: { selectedLocation = location }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Admin Shift Row
struct AdminShiftRow: View {
    let shift: Shift
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Time column
            VStack(alignment: .center, spacing: 2) {
                Text(formatTime(shift.startTime))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                Text("to")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                Text(formatTime(shift.endTime))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            .frame(width: 60)
            
            // Divider
            Rectangle()
                .fill(locationColor)
                .frame(width: 3)
                .cornerRadius(2)
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: shift.location.icon)
                        .foregroundColor(locationColor)
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                Text(shift.assigneeName)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                
                if let notes = shift.notes, !notes.isEmpty {
                    Text(notes)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                // Status indicators
                HStack(spacing: Theme.Spacing.sm) {
                    if shift.acknowledged {
                        Label("Acknowledged", systemImage: "checkmark.circle.fill")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.connected)
                    } else if !shift.isPast {
                        Label("Pending", systemImage: "clock")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(Theme.Colors.emergency.opacity(0.7))
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var locationColor: Color {
        switch shift.location {
        case .bus: return Theme.Colors.sunsetOrange
        case .shadyBot: return Theme.Colors.turquoise
        case .camp: return Theme.Colors.robotCream
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Empty Day View
struct EmptyDayView: View {
    let date: Date
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No shifts scheduled")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            
            Text("Tap + to add a shift for \(formatDate(date))")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .padding(Theme.Spacing.xl)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Create Shift View
struct CreateShiftView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    let initialDate: Date
    
    @State private var selectedMember: CampMember?
    @State private var selectedLocation: Shift.ShiftLocation = .bus
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var notes: String = ""
    
    init(initialDate: Date) {
        self.initialDate = initialDate
        
        // Set default times based on the selected date
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: initialDate)
        components.hour = 22 // Default to 10 PM
        components.minute = 0
        let defaultStart = calendar.date(from: components) ?? initialDate
        
        _startTime = State(initialValue: defaultStart)
        _endTime = State(initialValue: defaultStart.addingTimeInterval(7200)) // 2 hours
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    // Member selection
                    Section {
                        Picker("Assign To", selection: $selectedMember) {
                            Text("Select member").tag(nil as CampMember?)
                            ForEach(meshtasticManager.campMembers) { member in
                                HStack {
                                    Image(systemName: member.role.icon)
                                    Text(member.name)
                                }
                                .tag(member as CampMember?)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Assignee")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Location
                    Section {
                        Picker("Location", selection: $selectedLocation) {
                            ForEach(Shift.ShiftLocation.allCases, id: \.self) { location in
                                HStack {
                                    Image(systemName: location.icon)
                                    Text(location.rawValue)
                                }
                                .tag(location)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Location")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Time
                    Section {
                        DatePicker("Start", selection: $startTime)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        DatePicker("End", selection: $endTime)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Time")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Duration: \(durationText)")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Notes
                    Section {
                        TextField("Optional notes", text: $notes)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Notes")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createShift()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(selectedMember == nil)
                }
            }
        }
    }
    
    private var durationText: String {
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hours"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func createShift() {
        guard let member = selectedMember else { return }
        
        shiftManager.createShift(
            assignedTo: member.id,
            assigneeName: member.name,
            location: selectedLocation,
            startTime: startTime,
            endTime: endTime,
            notes: notes.isEmpty ? nil : notes
        )
        
        dismiss()
    }
}

#Preview {
    ShiftAdminView()
        .environmentObject(ShiftManager())
        .environmentObject(MeshtasticManager())
}
