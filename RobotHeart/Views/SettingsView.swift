import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shiftManager: ShiftManager
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
                        // Ghost Mode toggle
                        Toggle(isOn: Binding(
                            get: { locationManager.isLocationPrivate },
                            set: { newValue in
                                if newValue {
                                    locationManager.enableGhostMode()
                                } else {
                                    locationManager.disableGhostMode()
                                }
                            }
                        )) {
                            HStack {
                                Image(systemName: "eye.slash.fill")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ghost Mode")
                                    Text("Hide your location from others")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                }
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                        .tint(Theme.Colors.sunsetOrange)
                        
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
                        .opacity(locationManager.isLocationPrivate ? 0.5 : 1.0)
                        .disabled(locationManager.isLocationPrivate)
                        
                        Toggle("Only when moved", isOn: .constant(true))
                            .foregroundColor(Theme.Colors.robotCream)
                            .tint(Theme.Colors.sunsetOrange)
                            .opacity(locationManager.isLocationPrivate ? 0.5 : 1.0)
                            .disabled(locationManager.isLocationPrivate)
                    } header: {
                        Text("Location & Privacy")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text(locationManager.isLocationPrivate ? 
                             "Your location is hidden. Battery and status are still shared." :
                             "Location updates are sent only when you've moved more than 50 meters")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Admin settings
                    Section {
                        Toggle(isOn: Binding(
                            get: { shiftManager.isAdmin },
                            set: { shiftManager.setAdminStatus($0) }
                        )) {
                            HStack {
                                Image(systemName: "shield.fill")
                                Text("Admin Mode")
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                        .tint(Theme.Colors.sunsetOrange)
                    } header: {
                        Text("Permissions")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Admins can create and assign shifts to camp members")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Notifications
                    Section {
                        HStack {
                            Image(systemName: "bell.fill")
                            Text("Shift Reminders")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            if shiftManager.notificationsEnabled {
                                Text("Enabled")
                                    .foregroundColor(Theme.Colors.connected)
                            } else {
                                Button("Enable") {
                                    shiftManager.requestNotificationPermissions()
                                }
                                .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                    } header: {
                        Text("Notifications")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Get reminded 15 minutes before your shifts")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
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

#Preview {
    SettingsView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
        .environmentObject(ShiftManager())
}
