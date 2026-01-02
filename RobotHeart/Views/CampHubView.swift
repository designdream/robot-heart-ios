import SwiftUI

// MARK: - Camp Hub View
// Central hub for all camp-related features: Roster, Maps, Camp Layout
struct CampHubView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedSection = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Section picker
                    Picker("Section", selection: $selectedSection) {
                        Text("Roster").tag(0)
                        Text("Playa Map").tag(1)
                        Text("Camp Map").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    TabView(selection: $selectedSection) {
                        RosterContentView()
                            .tag(0)
                        
                        MapContentView()
                            .tag(1)
                        
                        CampMapContentView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Camp")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
}

// MARK: - Roster Content View (embedded version)
struct RosterContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var checkInManager: CheckInManager
    @State private var selectedRole: CampMember.Role? = nil
    @State private var searchText: String = ""
    @State private var selectedMember: CampMember?
    @State private var showingMemberDetail = false
    
    var filteredMembers: [CampMember] {
        var members = meshtasticManager.campMembers
        
        if let role = selectedRole {
            members = members.filter { $0.role == role }
        }
        
        if !searchText.isEmpty {
            members = members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return members
    }
    
    var onlineCount: Int {
        meshtasticManager.campMembers.filter { $0.isOnline }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                TextField("Search members...", text: $searchText)
                    .foregroundColor(Theme.Colors.robotCream)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                // Online count
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.Colors.connected)
                        .frame(width: 8, height: 8)
                    Text("\(onlineCount)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
            .padding(Theme.Spacing.sm)
            .background(Theme.Colors.backgroundMedium)
            
            // Role filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    RoleChip(title: "All", isSelected: selectedRole == nil) {
                        selectedRole = nil
                    }
                    
                    ForEach(CampMember.Role.allCases, id: \.self) { role in
                        RoleChip(title: role.rawValue, icon: role.icon, isSelected: selectedRole == role) {
                            selectedRole = role
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.sm)
            }
            
            // Members list
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    ForEach(filteredMembers) { member in
                        MemberRowCard(member: member)
                            .onTapGesture {
                                selectedMember = member
                                showingMemberDetail = true
                            }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingMemberDetail) {
            if let member = selectedMember {
                MemberDetailView(member: member)
            }
        }
    }
}

// MARK: - Member Row Card (compact)
struct MemberRowCard: View {
    let member: CampMember
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.backgroundLight)
                    .frame(width: 40, height: 40)
                
                Text(member.name.prefix(1))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: member.role.icon)
                        .font(.caption2)
                    Text(member.role.rawValue)
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            // Battery if available
            if let battery = member.batteryLevel {
                HStack(spacing: 2) {
                    Image(systemName: batteryIcon(battery))
                        .font(.caption)
                    Text("\(battery)%")
                        .font(Theme.Typography.caption)
                }
                .foregroundColor(batteryColor(battery))
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private var statusColor: Color {
        switch member.status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.disconnected
        }
    }
    
    private func batteryIcon(_ level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        default: return "battery.25"
        }
    }
    
    private func batteryColor(_ level: Int) -> Color {
        switch level {
        case 50...100: return Theme.Colors.connected
        case 25..<50: return Theme.Colors.warning
        default: return Theme.Colors.emergency
        }
    }
}

// MARK: - Role Chip
struct RoleChip: View {
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
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Map Content View (embedded)
struct MapContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var emergencyManager: EmergencyManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Map placeholder (in production, use MapKit)
            ZStack {
                Theme.Colors.backgroundMedium
                
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                    
                    Text("Playa Map")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("See camp members on the playa")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    
                    NavigationLink(destination: MapView()) {
                        Text("Open Full Map")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(Theme.Colors.sunsetOrange)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                }
            }
            
            // Location sharing controls
            VStack(spacing: Theme.Spacing.sm) {
                HStack {
                    Image(systemName: locationManager.isLocationPrivate ? "eye.slash.fill" : "location.fill")
                        .foregroundColor(locationManager.isLocationPrivate ? Theme.Colors.warning : Theme.Colors.connected)
                    
                    Text(locationManager.isLocationPrivate ? "Ghost Mode On" : "Location Sharing")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { !locationManager.isLocationPrivate },
                        set: { sharing in
                            if sharing {
                                locationManager.disableGhostMode()
                            } else {
                                locationManager.enableGhostMode()
                            }
                        }
                    ))
                    .tint(Theme.Colors.sunsetOrange)
                }
                
                // SOS Button
                SOSButtonView()
            }
            .padding()
            .background(Theme.Colors.backgroundDark)
        }
    }
}

// MARK: - Camp Map Content View (embedded)
struct CampMapContentView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftManager: ShiftManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Camp map
            GeometryReader { geometry in
                ZStack {
                    if let imageData = profileManager.campMap.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Structure markers
                        ForEach(profileManager.campMap.structures) { structure in
                            StructureMarker(structure: structure)
                                .position(
                                    x: structure.xPosition * geometry.size.width,
                                    y: structure.yPosition * geometry.size.height
                                )
                        }
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "map")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                            
                            Text("No Camp Map")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            if shiftManager.isAdmin {
                                NavigationLink(destination: CampMapView()) {
                                    Text("Upload Map")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.backgroundDark)
                                        .padding(.horizontal, Theme.Spacing.lg)
                                        .padding(.vertical, Theme.Spacing.sm)
                                        .background(Theme.Colors.sunsetOrange)
                                        .cornerRadius(Theme.CornerRadius.md)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.Colors.backgroundMedium)
                    }
                }
            }
            
            // Structure list
            if !profileManager.campMap.structures.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(profileManager.campMap.structures) { structure in
                            NavigationLink(destination: StructureDetailView(structure: structure)) {
                                VStack(spacing: 4) {
                                    Image(systemName: structure.type.icon)
                                        .foregroundColor(Theme.Colors.turquoise)
                                    Text(structure.name)
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.robotCream)
                                    Text("\(structure.assignedMembers.count)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Colors.backgroundMedium)
                                .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                    }
                    .padding()
                }
                .background(Theme.Colors.backgroundDark)
            }
        }
    }
}

#Preview {
    CampHubView()
        .environmentObject(MeshtasticManager())
        .environmentObject(ProfileManager())
        .environmentObject(CheckInManager())
        .environmentObject(LocationManager())
        .environmentObject(EmergencyManager())
        .environmentObject(ShiftManager())
}
