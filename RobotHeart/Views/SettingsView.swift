import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var userName = "You"
    @State private var selectedRole: CampMember.Role = .general
    @State private var shareInterval: Double = 15
    @State private var showingDeviceScanner = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    // Profile section
                    Section {
                        HStack {
                            Text("Name")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            TextField("Your name", text: $userName)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                        
                        Picker("Role", selection: $selectedRole) {
                            ForEach(CampMember.Role.allCases, id: \.self) { role in
                                HStack {
                                    Image(systemName: role.icon)
                                    Text(role.rawValue)
                                }
                                .tag(role)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Profile")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Meshtastic connection
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Device")
                                    .foregroundColor(Theme.Colors.robotCream)
                                if let device = meshtasticManager.connectedDevice {
                                    Text(device)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                                }
                            }
                            
                            Spacer()
                            
                            if meshtasticManager.isConnected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.connected)
                            } else {
                                Button("Connect") {
                                    showingDeviceScanner = true
                                }
                                .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                        
                        if !meshtasticManager.isConnected {
                            Button(action: {
                                meshtasticManager.startScanning()
                            }) {
                                HStack {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text("Scan for Devices")
                                }
                                .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                    } header: {
                        Text("Meshtastic Connection")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Location settings
                    Section {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Text("Share Interval")
                                    .foregroundColor(Theme.Colors.robotCream)
                                Spacer()
                                Text("\(Int(shareInterval)) min")
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                            
                            Slider(value: $shareInterval, in: 5...60, step: 5)
                                .accentColor(Theme.Colors.sunsetOrange)
                                .onChange(of: shareInterval) { newValue in
                                    if locationManager.isSharing {
                                        locationManager.startSharing(interval: newValue * 60)
                                    }
                                }
                        }
                        
                        Toggle("Only when moved", isOn: .constant(true))
                            .foregroundColor(Theme.Colors.robotCream)
                            .tint(Theme.Colors.sunsetOrange)
                    } header: {
                        Text("Location Sharing")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Location updates are sent only when you've moved more than 50 meters")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Shift management
                    Section {
                        NavigationLink(destination: ShiftScheduleView()) {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Shift Schedule")
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                    } header: {
                        Text("Shifts")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // About
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            Text("1.0.0")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        }
                        
                        Link(destination: URL(string: "https://www.robotheart.org")!) {
                            HStack {
                                Image(systemName: "heart.fill")
                                Text("Robot Heart")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    } header: {
                        Text("About")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
}

// MARK: - Shift Schedule View
struct ShiftScheduleView: View {
    @State private var shifts: [ShiftEntry] = []
    @State private var showingAddShift = false
    
    struct ShiftEntry: Identifiable {
        let id = UUID()
        var location: CampMember.Shift.ShiftLocation
        var startTime: Date
        var endTime: Date
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack {
                if shifts.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        Text("No shifts scheduled")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text("Add your shifts on the bus or Shady Bot")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(shifts) { shift in
                            ShiftRow(shift: shift)
                        }
                        .onDelete(perform: deleteShifts)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Shift Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddShift = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
        .sheet(isPresented: $showingAddShift) {
            AddShiftView(onAdd: { shift in
                shifts.append(shift)
                showingAddShift = false
            })
        }
    }
    
    private func deleteShifts(at offsets: IndexSet) {
        shifts.remove(atOffsets: offsets)
    }
}

// MARK: - Shift Row
struct ShiftRow: View {
    let shift: ShiftScheduleView.ShiftEntry
    
    var body: some View {
        HStack {
            Image(systemName: shift.location == .bus ? "bus.fill" : "sun.max.fill")
                .foregroundColor(Theme.Colors.turquoise)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(shift.location.rawValue)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("\(timeString(shift.startTime)) - \(timeString(shift.endTime))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
        .listRowBackground(Theme.Colors.backgroundMedium)
    }
    
    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Shift View
struct AddShiftView: View {
    let onAdd: (ShiftScheduleView.ShiftEntry) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedLocation: CampMember.Shift.ShiftLocation = .bus
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        Picker("Location", selection: $selectedLocation) {
                            Text("Robot Heart Bus").tag(CampMember.Shift.ShiftLocation.bus)
                            Text("Shady Bot").tag(CampMember.Shift.ShiftLocation.shadyBot)
                            Text("Camp").tag(CampMember.Shift.ShiftLocation.camp)
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        DatePicker("Start Time", selection: $startTime)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        DatePicker("End Time", selection: $endTime)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let shift = ShiftScheduleView.ShiftEntry(
                            location: selectedLocation,
                            startTime: startTime,
                            endTime: endTime
                        )
                        onAdd(shift)
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
}
