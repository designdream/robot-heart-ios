import SwiftUI

// MARK: - Places View
/// Central hub for location-based features: Maps, Camp Layout, Nearby Camps
/// Renamed from "Camp" to "Places" for clearer purpose and scalability beyond Burning Man
struct PlacesView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var layoutManager: CampLayoutManager
    @EnvironmentObject var campNetworkManager: CampNetworkManager
    @State private var selectedSection = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Section picker
                    Picker("Section", selection: $selectedSection) {
                        Text("Map").tag(0)
                        Text("Our Camp").tag(1)
                        Text("Nearby").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    TabView(selection: $selectedSection) {
                        // Playa Map - BRC grid, member locations
                        PlayaMapContentView()
                            .tag(0)
                        
                        // Our Camp Layout - the camp planner
                        CampLayoutPlannerView()
                            .tag(1)
                        
                        // Nearby Camps - discovered via mesh
                        NearbyCampsContentView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Places")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: CommunityView()) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(meshtasticManager.campMembers.count)")
                                .font(Theme.Typography.caption)
                        }
                        .foregroundColor(Theme.Colors.turquoise)
                    }
                }
            }
        }
    }
}

// MARK: - Playa Map Content View
struct PlayaMapContentView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Map placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                        .fill(Theme.Colors.backgroundLight)
                        .frame(height: 300)
                    
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "map")
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                        
                        Text("Playa Map")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text("BRC street grid coming soon")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                // Members with shared locations
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("PEOPLE NEARBY")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    let membersWithLocation = meshtasticManager.campMembers.filter { 
                        $0.lastKnownLocation != nil && !$0.isGhostMode 
                    }
                    
                    if membersWithLocation.isEmpty {
                        Text("No one is sharing their location right now")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.Colors.backgroundLight)
                            .cornerRadius(Theme.CornerRadius.md)
                    } else {
                        ForEach(membersWithLocation) { member in
                            MemberLocationRow(member: member)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Member Location Row
struct MemberLocationRow: View {
    let member: CampMember
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.turquoise.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(String(member.name.prefix(1)))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.turquoise)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.robotCream)
                
                if member.lastKnownLocation != nil {
                    Text("Last seen \(timeAgo(member.lastSeen))")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            Spacer()
            
            // Online indicator
            Circle()
                .fill(member.isOnline ? Theme.Colors.connected : Theme.Colors.robotCream.opacity(0.3))
                .frame(width: 10, height: 10)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
}

// MARK: - Nearby Camps Content View
struct NearbyCampsContentView: View {
    @EnvironmentObject var campNetworkManager: CampNetworkManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                // Our camp (if set up)
                if let myCamp = campNetworkManager.myCamp {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text("OUR CAMP")
                            .font(Theme.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            .tracking(0.5)
                        
                        OurCampCard(camp: myCamp)
                    }
                }
                
                // Discovered camps
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("NEARBY CAMPS")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    if campNetworkManager.discoveredCamps.isEmpty {
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 36))
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                            
                            Text("No camps discovered yet")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Text("Camps using Robot Heart will appear here when in range")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.lg)
                    } else {
                        ForEach(campNetworkManager.discoveredCamps) { camp in
                            DiscoveredCampCard(camp: camp)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Our Camp Card
struct OurCampCard: View {
    let camp: CampInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "house.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(camp.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(camp.location)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                Text("\(camp.memberCount) members")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.turquoise)
            }
            
            if let description = camp.description {
                Text(description)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Colors.sunsetOrange.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                .stroke(Theme.Colors.sunsetOrange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Discovered Camp Card
struct DiscoveredCampCard: View {
    let camp: DiscoveredCamp
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tent.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.turquoise)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.turquoise.opacity(0.15))
                .cornerRadius(Theme.CornerRadius.md)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(camp.name)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Label(camp.location, systemImage: "mappin")
                    Label("\(camp.memberCount)", systemImage: "person.2")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Spacer()
            
            // Signal strength
            SignalStrengthIndicator(strength: camp.signalStrength)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Community View (People/Roster)
/// Renamed from "Roster" to "Community" for warmer, more personal feel
struct CommunityView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var checkInManager: CheckInManager
    @State private var selectedRole: CampMember.Role? = nil
    @State private var searchText: String = ""
    
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
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search and filter
                VStack(spacing: Theme.Spacing.sm) {
                    // Search bar
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                        
                        TextField("Search people...", text: $searchText)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                            }
                        }
                        
                        // Online count
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Theme.Colors.connected)
                                .frame(width: 8, height: 8)
                            Text("\(onlineCount)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.connected)
                        }
                    }
                    .padding(Theme.Spacing.md)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                    
                    // Role filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            RoleFilterPill(title: "All", isSelected: selectedRole == nil) {
                                selectedRole = nil
                            }
                            
                            ForEach(CampMember.Role.allCases, id: \.self) { role in
                                RoleFilterPill(
                                    title: role.rawValue,
                                    isSelected: selectedRole == role
                                ) {
                                    selectedRole = role
                                }
                            }
                        }
                    }
                }
                .padding()
                
                // Members list
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filteredMembers) { member in
                            NavigationLink(destination: MemberDetailView(member: member)) {
                                CommunityMemberRow(member: member)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Community")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Role Filter Pill
struct RoleFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Theme.Colors.turquoise : Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.sm)
        }
    }
}

// MARK: - Community Member Row
struct CommunityMemberRow: View {
    let member: CampMember
    
    var roleColor: Color {
        switch member.role {
        case .lead: return Theme.Colors.goldenYellow
        case .bus: return Theme.Colors.sunsetOrange
        case .shadyBot: return Theme.Colors.goldenYellow
        case .build: return Theme.Colors.turquoise
        case .med: return Theme.Colors.emergency
        case .perimeter: return Theme.Colors.turquoise
        case .bike: return Theme.Colors.connected
        case .general: return Theme.Colors.robotCream
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(member.name.prefix(1)))
                    .font(Theme.Typography.headline)
                    .foregroundColor(roleColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(member.name)
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if member.isOnline {
                        Circle()
                            .fill(Theme.Colors.connected)
                            .frame(width: 8, height: 8)
                    }
                }
                
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: member.role.icon)
                        .font(.system(size: 10))
                    Text(member.role.rawValue)
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

#Preview {
    PlacesView()
        .environmentObject(MeshtasticManager())
        .environmentObject(ProfileManager())
        .environmentObject(CampLayoutManager())
        .environmentObject(CampNetworkManager.shared)
        .environmentObject(LocationManager())
}
