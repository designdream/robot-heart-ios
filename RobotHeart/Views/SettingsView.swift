import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var checkInManager: CheckInManager
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    @EnvironmentObject var economyManager: EconomyManager
    @State private var userName = "You"
    @State private var showingResetConfirmation = false
    @State private var selectedRole: CampMember.Role = .general
    @State private var shareInterval: Double = 15
    @State private var showingDeviceScanner = false
    @State private var showingBorderCrossing = false
    @State private var showingPrivacySettings = false
    
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
                    
                    // Safety Check-In (Opt-in)
                    Section {
                        Toggle(isOn: Binding(
                            get: { checkInManager.checkInEnabled },
                            set: { checkInManager.setCheckInEnabled($0) }
                        )) {
                            HStack {
                                Image(systemName: "heart.text.square.fill")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Safety Check-In")
                                    Text("Periodic reminders to let camp know you're OK")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                }
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                        .tint(Theme.Colors.sunsetOrange)
                        
                        if checkInManager.checkInEnabled {
                            Picker("Interval", selection: Binding(
                                get: { checkInManager.checkInInterval },
                                set: { checkInManager.setCheckInInterval($0) }
                            )) {
                                Text("2 hours").tag(TimeInterval(7200))
                                Text("4 hours").tag(TimeInterval(14400))
                                Text("6 hours").tag(TimeInterval(21600))
                                Text("8 hours").tag(TimeInterval(28800))
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                    } header: {
                        Text("Safety")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text(checkInManager.checkInEnabled ?
                             "You'll get reminders to check in. Your camp can see if you're overdue." :
                             "Off by default. Enable if you want periodic safety check-in reminders.")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Security & Biometrics
                    Section {
                        Toggle(isOn: Binding(
                            get: { biometricAuthManager.isEnabled },
                            set: { biometricAuthManager.isEnabled = $0 }
                        )) {
                            HStack {
                                Image(systemName: biometricIcon)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(biometricAuthManager.biometricType.rawValue) Lock")
                                    Text("Require authentication to open app")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                }
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                        }
                        .tint(Theme.Colors.sunsetOrange)
                        .disabled(!biometricAuthManager.isBiometricAvailable)
                        
                        if biometricAuthManager.isEnabled {
                            Toggle(isOn: Binding(
                                get: { biometricAuthManager.requireAuthOnLaunch },
                                set: { biometricAuthManager.requireAuthOnLaunch = $0 }
                            )) {
                                HStack {
                                    Image(systemName: "lock.shield.fill")
                                    Text("Lock on App Launch")
                                }
                                .foregroundColor(Theme.Colors.robotCream)
                            }
                            .tint(Theme.Colors.sunsetOrange)
                        }
                    } header: {
                        Text("Security")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text(biometricAuthManager.isBiometricAvailable ?
                             "Biometric authentication works completely offline - perfect for the playa." :
                             "No biometric authentication available on this device.")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    // Privacy & Data
                    Section {
                        // Border Crossing Mode
                        Button(action: { showingBorderCrossing = true }) {
                            HStack {
                                Image(systemName: "airplane.departure")
                                    .foregroundColor(Theme.Colors.warning)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Border Crossing Mode")
                                        .foregroundColor(Theme.Colors.robotCream)
                                    Text("Clear messages, keep contacts & capital")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                            }
                        }
                        
                        // Privacy Settings
                        Button(action: { showingPrivacySettings = true }) {
                            HStack {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(Theme.Colors.turquoise)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Privacy Settings")
                                        .foregroundColor(Theme.Colors.robotCream)
                                    Text("Message retention, storage options")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                            }
                        }
                    } header: {
                        Text("Privacy & Data")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Your data is stored locally. Control how long messages are kept and prepare for travel.")
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
                    
                    // Developer / Debug section
                    Section {
                        // Show current burn stats
                        HStack {
                            Text("Your Burn")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            Text("\(economyManager.myStanding.pointsEarned) burn, \(economyManager.myStanding.shiftsCompleted) contributions")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        }
                        
                        // Reset burn data
                        Button(action: { showingResetConfirmation = true }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset Burn Data")
                            }
                            .foregroundColor(Theme.Colors.emergency)
                        }
                    } header: {
                        Text("Developer")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Reset will clear your contribution history. Use for testing only.")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
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
            .sheet(isPresented: $showingBorderCrossing) {
                BorderCrossingView()
            }
            .sheet(isPresented: $showingPrivacySettings) {
                SCPrivacySettingsView()
            }
            .alert("Reset Burn Data?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    economyManager.resetStanding()
                }
            } message: {
                Text("This will reset your contribution history to 0. This cannot be undone.")
            }
        }
    }
    
    private var biometricIcon: String {
        switch biometricAuthManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.fill"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
        .environmentObject(ShiftManager())
        .environmentObject(CheckInManager())
        .environmentObject(BiometricAuthManager.shared)
        .environmentObject(EconomyManager())
}
