import SwiftUI

struct RosterView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var checkInManager: CheckInManager
    @State private var selectedRole: CampMember.Role? = nil
    @State private var showingAddMember = false
    @State private var searchText: String = ""
    @State private var selectedMember: CampMember?
    @State private var showingMemberDetail = false
    
    var filteredMembers: [CampMember] {
        var members = meshtasticManager.campMembers
        
        // Filter by role
        if let role = selectedRole {
            members = members.filter { $0.role == role }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            members = members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return members
    }
    
    var onlineCount: Int {
        meshtasticManager.campMembers.filter { $0.isOnline }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with connection status
                    headerView
                    
                    // Search bar
                    searchBar
                    
                    // Role filter
                    roleFilterView
                    
                    // Members list
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            // Check-in card at top
                            CheckInCard()
                            
                            // Overdue members alert
                            OverdueMembersView()
                            
                            ForEach(filteredMembers) { member in
                                MemberCard(member: member)
                                    .onTapGesture {
                                        selectedMember = member
                                        showingMemberDetail = true
                                    }
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                            .font(.title3)
                        Text("Robot Heart")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
            }
        }
        .sheet(isPresented: $showingMemberDetail) {
            if let member = selectedMember {
                MemberDetailView(member: member)
            }
        }
    }
    
    private var searchBar: some View {
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
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.backgroundMedium)
    }
    
    private var headerView: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                // Connection status
                ConnectionStatusBadge(
                    isConnected: meshtasticManager.isConnected,
                    deviceName: meshtasticManager.connectedDevice
                )
                
                Spacer()
                
                // Online count
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(Theme.Colors.connected)
                        .frame(width: 8, height: 8)
                    
                    Text("\(onlineCount)/\(meshtasticManager.campMembers.count)")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
            .padding(.horizontal)
            .padding(.top, Theme.Spacing.sm)
        }
    }
    
    private var roleFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                RoleFilterChip(
                    title: "All",
                    isSelected: selectedRole == nil,
                    action: { selectedRole = nil }
                )
                
                ForEach(CampMember.Role.allCases, id: \.self) { role in
                    RoleFilterChip(
                        title: role.rawValue,
                        icon: role.icon,
                        isSelected: selectedRole == role,
                        action: { selectedRole = role }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Member Card
struct MemberCard: View {
    let member: CampMember
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Colors.backgroundLight)
                        .frame(width: 50, height: 50)
                    
                    Text(member.name.prefix(1))
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if member.currentShift?.isActive == true {
                            Image(systemName: "clock.fill")
                                .foregroundColor(Theme.Colors.turquoise)
                                .font(.caption)
                        }
                    }
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: member.role.icon)
                            .font(.caption)
                        Text(member.role.rawValue)
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Status indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(statusColor(for: member.status))
                            .frame(width: 8, height: 8)
                        
                        Text(member.lastSeenText)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Battery level
                    if let battery = member.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(for: battery))
                                .font(.caption)
                            Text("\(battery)%")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(batteryColor(for: battery))
                    }
                }
            }
            
            // Shift info if active
            if let shift = member.currentShift, shift.isActive {
                HStack {
                    Image(systemName: "bus.fill")
                        .foregroundColor(Theme.Colors.turquoise)
                    Text("On shift: \(shift.location.rawValue)")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.turquoise)
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func statusColor(for status: CampMember.ConnectionStatus) -> Color {
        switch status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.disconnected
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 75...100: return "battery.100"
        case 50..<75: return "battery.75"
        case 25..<50: return "battery.50"
        case 10..<25: return "battery.25"
        default: return "battery.0"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 50...100: return Theme.Colors.connected
        case 25..<50: return Theme.Colors.warning
        default: return Theme.Colors.disconnected
        }
    }
}

// MARK: - Connection Status Badge
struct ConnectionStatusBadge: View {
    let isConnected: Bool
    let deviceName: String?
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle()
                .fill(isConnected ? Theme.Colors.connected : Theme.Colors.disconnected)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .animation(Theme.Animations.heartbeat, value: isPulsing)
            
            Text(isConnected ? (deviceName ?? "Connected") : "Disconnected")
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.robotCream)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
        .onAppear {
            if isConnected {
                isPulsing = true
            }
        }
    }
}

// MARK: - Role Filter Chip
struct RoleFilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(Theme.Typography.callout)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
            .foregroundColor(isSelected ? .white : Theme.Colors.robotCream)
            .cornerRadius(Theme.CornerRadius.lg)
        }
        .animation(Theme.Animations.quick, value: isSelected)
    }
}

#Preview {
    RosterView()
        .environmentObject(MeshtasticManager())
        .environmentObject(CheckInManager())
}
