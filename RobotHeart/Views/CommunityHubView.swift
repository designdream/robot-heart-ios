import SwiftUI

// MARK: - Community Hub View
/// THE CORE of the Burning Man experience: Human Connection
/// Research shows this is the #1 reason people participate in Burning Man
/// "Real connection with humans... relating to people face to face, eye contact, hugs"
struct CommunityHubView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var selectedFilter: CommunityFilter = .connections
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case map = "Map"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .map: return "map"
            }
        }
    }
    
    enum CommunityFilter: String, CaseIterable {
        case all = "All"
        case online = "Online Now"
        case nearby = "Nearby"
        case connections = "My Connections"
        
        var icon: String {
            switch self {
            case .all: return "person.3"
            case .online: return "wifi"
            case .nearby: return "location"
            case .connections: return "heart"
            }
        }
    }
    
    var filteredMembers: [CampMember] {
        var members = meshtasticManager.campMembers
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .online:
            members = members.filter { $0.isOnline }
        case .nearby:
            // TODO: Filter by GPS proximity
            members = members.filter { $0.isOnline }
        case .connections:
            members = members.filter { profileManager.approvedContacts.contains($0.id) }
        }
        
        // Apply search
        if !searchText.isEmpty {
            members = members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort: online first, then by name
        return members.sorted { 
            if $0.isOnline != $1.isOnline { return $0.isOnline }
            return $0.name < $1.name
        }
    }
    
    var onlineCount: Int {
        meshtasticManager.campMembers.filter { $0.isOnline }.count
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // View mode toggle (List / Map) - pill style, no background
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Button(action: { 
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewMode = mode 
                                }
                            }) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 12))
                                    Text(mode.rawValue)
                                        .font(Theme.Typography.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(viewMode == mode ? Theme.Colors.backgroundDark : Theme.Colors.robotCream.opacity(0.7))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(viewMode == mode ? Theme.Colors.turquoise : Theme.Colors.backgroundLight)
                                .cornerRadius(Theme.CornerRadius.full)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    
                    // Search bar (always visible)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        TextField("Find someone...", text: $searchText)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundLight)
                    
                    // Content based on view mode
                    if viewMode == .list {
                        // LIST VIEW
                        // Connection status header
                        ConnectionStatusHeader(
                            totalMembers: meshtasticManager.campMembers.count,
                            onlineCount: onlineCount,
                            myConnectionsCount: profileManager.approvedContacts.count
                        )
                        
                        // Filter chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.sm) {
                                ForEach(CommunityFilter.allCases, id: \.self) { filter in
                                    CommunityFilterChip(
                                        title: filter.rawValue,
                                        icon: filter.icon,
                                        isSelected: selectedFilter == filter,
                                        count: countForFilter(filter)
                                    ) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, Theme.Spacing.sm)
                        }
                        
                        // Members list
                        ScrollView {
                            LazyVStack(spacing: Theme.Spacing.sm) {
                                if profileManager.approvedContacts.isEmpty && selectedFilter == .connections {
                                    EmptyConnectionsPrompt()
                                } else if filteredMembers.isEmpty {
                                    EmptySearchResult(searchText: searchText, filter: selectedFilter)
                                } else {
                                    ForEach(filteredMembers) { member in
                                        NavigationLink(destination: CommunityMemberDetailView(member: member)) {
                                            CommunityMemberCard(member: member)
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    } else {
                        // MAP VIEW - See your community spatially
                        CommunityMapView(
                            members: filteredMembers,
                            searchText: $searchText
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Community")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                // NOTE: Removed map icon - redundant with List/Map toggle
            }
        }
    }
    
    func countForFilter(_ filter: CommunityFilter) -> Int? {
        switch filter {
        case .all: return nil
        case .online: return onlineCount
        case .nearby: return nil
        case .connections: return profileManager.approvedContacts.count
        }
    }
}

// MARK: - Connection Status Header
struct ConnectionStatusHeader: View {
    let totalMembers: Int
    let onlineCount: Int
    let myConnectionsCount: Int
    
    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Online now
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.Colors.connected)
                        .frame(width: 8, height: 8)
                    Text("\(onlineCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.robotCream)
                }
                Text("Online")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Divider()
                .frame(height: 40)
                .background(Theme.Colors.robotCream.opacity(0.2))
            
            // Total members
            VStack(spacing: 4) {
                Text("\(totalMembers)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.robotCream)
                Text("Camp Members")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Divider()
                .frame(height: 40)
                .background(Theme.Colors.robotCream.opacity(0.2))
            
            // My connections
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.dustyPink)
                    Text("\(myConnectionsCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.robotCream)
                }
                Text("Connections")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Community Filter Chip
struct CommunityFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(Theme.Typography.caption)
                if let count = count, count > 0 {
                    Text("(\(count))")
                        .font(Theme.Typography.caption)
                }
            }
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? Theme.Colors.turquoise : Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Community Member Card
struct CommunityMemberCard: View {
    let member: CampMember
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var economyManager: EconomyManager
    
    var isConnection: Bool {
        profileManager.approvedContacts.contains(member.id)
    }
    
    // Get member's burn from leaderboard (or mock based on member ID for demo)
    var memberBurn: Int {
        // Check leaderboard for this member
        if let entry = economyManager.leaderboard.first(where: { $0.memberID == member.id }) {
            return entry.points
        }
        // For demo: generate consistent burn based on member ID hash
        let hash = abs(member.id.hashValue)
        return (hash % 100) + (member.isOnline ? 10 : 0)
    }
    
    var burnBadge: (icon: String, color: Color, label: String) {
        switch memberBurn {
        case 100...: return ("flame.fill", Theme.Colors.goldenYellow, "🔥")
        case 50..<100: return ("flame.fill", Theme.Colors.sunsetOrange, "")
        case 20..<50: return ("flame", Theme.Colors.sunsetOrange.opacity(0.7), "")
        case 1..<20: return ("flame", Theme.Colors.robotCream.opacity(0.5), "")
        default: return ("", .clear, "")
        }
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(roleColor)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                if member.isOnline {
                    Circle()
                        .fill(Theme.Colors.connected)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.backgroundLight, lineWidth: 2)
                        )
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(member.name)
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if isConnection {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.dustyPink)
                    }
                    
                    // Burn badge - badge of honor!
                    if memberBurn > 0 {
                        BurnBadge(burn: memberBurn)
                    }
                }
                
                HStack(spacing: Theme.Spacing.sm) {
                    // Role
                    HStack(spacing: 2) {
                        Image(systemName: member.role.icon)
                            .font(.system(size: 10))
                        Text(member.role.rawValue)
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(roleColor)
                    
                    // Status
                    if member.isOnline {
                        Text("• Online")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.connected)
                    } else {
                        Text("• \(timeAgo(member.lastSeen))")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                    }
                }
            }
            
            Spacer()
            
            // Quick actions
            if member.isOnline {
                Button(action: {}) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Theme.Colors.turquoise)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.turquoise.opacity(0.15))
                        .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    var roleColor: Color {
        switch member.role {
        case .lead: return Theme.Colors.goldenYellow
        case .bus: return Theme.Colors.sunsetOrange
        case .shadyBot: return Theme.Colors.goldenYellow
        case .build: return Theme.Colors.turquoise
        case .med: return Theme.Colors.emergency
        case .perimeter: return Theme.Colors.turquoise
        case .bike: return Theme.Colors.connected
        case .general: return Theme.Colors.robotCream.opacity(0.7)
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Burn Badge
/// Shows member's burn contribution as a badge of honor
struct BurnBadge: View {
    let burn: Int
    
    var badgeColor: Color {
        switch burn {
        case 100...: return Theme.Colors.goldenYellow
        case 50..<100: return Theme.Colors.sunsetOrange
        case 20..<50: return Theme.Colors.sunsetOrange.opacity(0.8)
        default: return Theme.Colors.robotCream.opacity(0.6)
        }
    }
    
    var badgeIcon: String {
        switch burn {
        case 50...: return "flame.fill"
        default: return "flame"
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: badgeIcon)
                .font(.system(size: 9))
            Text("\(burn)")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(badgeColor)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .cornerRadius(Theme.CornerRadius.full)
    }
}

// MARK: - Empty Connections Prompt
struct EmptyConnectionsPrompt: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "heart.circle")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.dustyPink.opacity(0.5))
            
            Text("No Connections Yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Burning Man is about human connection.\nScan someone's QR code to connect!")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: ProfileView()) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                    Text("Go to My QR Code")
                }
                .font(Theme.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding()
                .background(Theme.Colors.turquoise)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Empty Search Result
struct EmptySearchResult: View {
    let searchText: String
    let filter: CommunityHubView.CommunityFilter
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "person.slash")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            if !searchText.isEmpty {
                Text("No one named \"\(searchText)\"")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            } else {
                Text("No one \(filter.rawValue.lowercased()) right now")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Community Member Detail View
struct CommunityMemberDetailView: View {
    let member: CampMember
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingAddNote = false
    @State private var noteText = ""
    
    var isConnection: Bool {
        profileManager.approvedContacts.contains(member.id)
    }
    
    var memberNote: MemberNote? {
        socialManager.memberNotes.first { $0.memberID == member.id }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Profile header
                    VStack(spacing: Theme.Spacing.md) {
                        // Avatar
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(roleColor)
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(member.name.prefix(2)).uppercased())
                                        .font(.system(size: 36, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            
                            if member.isOnline {
                                Circle()
                                    .fill(Theme.Colors.connected)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(Theme.Colors.backgroundDark, lineWidth: 3)
                                    )
                            }
                        }
                        
                        Text(member.name)
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        // Role badge
                        HStack(spacing: 4) {
                            Image(systemName: member.role.icon)
                            Text(member.role.rawValue)
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(roleColor)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(roleColor.opacity(0.15))
                        .cornerRadius(Theme.CornerRadius.full)
                        
                        // Status
                        if member.isOnline {
                            Text("Online now")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.connected)
                        } else {
                            Text("Last seen \(timeAgo(member.lastSeen))")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.lg)
                    
                    // Quick actions
                    HStack(spacing: Theme.Spacing.md) {
                        CommunityActionButton(icon: "message.fill", title: "Message", color: Theme.Colors.turquoise) {
                            // TODO: Open DM
                        }
                        
                        if isConnection {
                            CommunityActionButton(icon: "heart.fill", title: "Connected", color: Theme.Colors.dustyPink) {
                                // Already connected
                            }
                        } else {
                            CommunityActionButton(icon: "heart", title: "Connect", color: Theme.Colors.dustyPink) {
                                profileManager.approvedContacts.append(member.id)
                            }
                        }
                        
                        CommunityActionButton(icon: "location.fill", title: "Find", color: Theme.Colors.connected) {
                            // TODO: Show on map
                        }
                    }
                    
                    // Private note
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: "note.text")
                                .foregroundColor(Theme.Colors.goldenYellow)
                            Text("Private Note")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Spacer()
                            
                            Button(action: { showingAddNote = true }) {
                                Image(systemName: memberNote == nil ? "plus.circle" : "pencil.circle")
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                            }
                        }
                        
                        if let note = memberNote {
                            Text(note.content)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                        } else {
                            Text("Add a private note about \(member.name)")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                                .italic()
                        }
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.lg)
                    
                    // Current shift (if any)
                    if let shift = member.currentShift {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(Theme.Colors.turquoise)
                                Text("Current Shift")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.robotCream)
                            }
                            
                            HStack {
                                Image(systemName: shiftLocationIcon(shift.location))
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                                Text(shift.location.rawValue)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.robotCream)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.lg)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddNote) {
            CommunityAddNoteSheet(memberID: member.id, memberName: member.name, existingNote: memberNote?.content ?? "")
        }
    }
    
    var roleColor: Color {
        switch member.role {
        case .lead: return Theme.Colors.goldenYellow
        case .bus: return Theme.Colors.sunsetOrange
        case .shadyBot: return Theme.Colors.goldenYellow
        case .build: return Theme.Colors.turquoise
        case .med: return Theme.Colors.emergency
        case .perimeter: return Theme.Colors.turquoise
        case .bike: return Theme.Colors.connected
        case .general: return Theme.Colors.robotCream.opacity(0.7)
        }
    }
    
    func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func shiftLocationIcon(_ location: CampMember.Shift.ShiftLocation) -> String {
        switch location {
        case .bus: return "bus.fill"
        case .shadyBot: return "sun.max.fill"
        case .camp: return "tent.fill"
        }
    }
}

// MARK: - Community Action Button
struct CommunityActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Text(title)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Community Add Note Sheet
struct CommunityAddNoteSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var socialManager: SocialManager
    let memberID: String
    let memberName: String
    @State var existingNote: String
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Private note about \(memberName)")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Only you can see this note")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    
                    TextEditor(text: $existingNote)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                        .scrollContentBackground(.hidden)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.md)
                        .frame(minHeight: 150)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    func saveNote() {
        if existingNote.isEmpty {
            // Delete note if empty
            socialManager.memberNotes.removeAll { $0.memberID == memberID }
        } else {
            // Update or create note
            if let index = socialManager.memberNotes.firstIndex(where: { $0.memberID == memberID }) {
                socialManager.memberNotes[index].content = existingNote
                socialManager.memberNotes[index].updatedAt = Date()
            } else {
                let note = MemberNote(
                    memberID: memberID,
                    content: existingNote
                )
                socialManager.memberNotes.append(note)
            }
        }
    }
}

// MARK: - Community Map View
/// See your community spatially - where are your people?
struct CommunityMapView: View {
    let members: [CampMember]
    @Binding var searchText: String
    @EnvironmentObject var locationManager: LocationManager
    @State private var selectedMember: CampMember?
    
    // Black Rock City center coordinates (approximate)
    private let brcCenter = (lat: 40.7864, lon: -119.2065)
    
    var body: some View {
        ZStack {
            // Map background
            Theme.Colors.backgroundDark
            
            // Playa grid visualization (simplified)
            GeometryReader { geometry in
                ZStack {
                    // Grid lines
                    PlayaGridOverlay()
                    
                    // Member pins (show all members, use hash-based position if no GPS)
                    ForEach(members) { member in
                        MemberMapPin(
                            member: member,
                            isSelected: selectedMember?.id == member.id,
                            geometry: geometry
                        )
                        .onTapGesture {
                            selectedMember = member
                        }
                    }
                    
                    // My location indicator
                    if locationManager.location != nil {
                        MyLocationIndicator(geometry: geometry)
                    }
                }
            }
            
            // Selected member card overlay
            if let member = selectedMember {
                VStack {
                    Spacer()
                    
                    SelectedMemberCard(member: member) {
                        selectedMember = nil
                    }
                    .padding()
                }
            }
            
            // Legend
            VStack {
                HStack {
                    Spacer()
                    MapLegend()
                        .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Playa Grid Overlay
struct PlayaGridOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Radial lines (streets from center)
                ForEach(0..<12, id: \.self) { i in
                    Path { path in
                        let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.7)
                        let angle = Double(i) * 30 * .pi / 180
                        let endX = center.x + cos(angle) * geometry.size.width
                        let endY = center.y - sin(angle) * geometry.size.width
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    }
                    .stroke(Theme.Colors.robotCream.opacity(0.1), lineWidth: 1)
                }
                
                // Concentric arcs (lettered streets)
                ForEach(1..<8, id: \.self) { i in
                    Circle()
                        .stroke(Theme.Colors.robotCream.opacity(0.1), lineWidth: 1)
                        .frame(width: CGFloat(i) * 80, height: CGFloat(i) * 80)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7)
                }
                
                // Center point (The Man)
                Circle()
                    .fill(Theme.Colors.sunsetOrange)
                    .frame(width: 12, height: 12)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7)
                
                Text("🔥")
                    .font(.system(size: 20))
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.7 - 20)
            }
        }
    }
}

// MARK: - Member Map Pin
struct MemberMapPin: View {
    let member: CampMember
    let isSelected: Bool
    let geometry: GeometryProxy
    
    // Convert member location to screen position (simplified)
    var position: CGPoint {
        // In production, use real GPS coordinates
        // For now, distribute members around the playa
        let hash = abs(member.id.hashValue)
        let angle = Double(hash % 360) * .pi / 180
        let distance = CGFloat(50 + (hash % 200))
        
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height * 0.7
        
        return CGPoint(
            x: centerX + Foundation.cos(angle) * Double(distance),
            y: centerY - Foundation.sin(angle) * Double(distance)
        )
    }
    
    var body: some View {
        ZStack {
            // Pin
            Circle()
                .fill(member.isOnline ? Theme.Colors.connected : Theme.Colors.backgroundLight)
                .frame(width: isSelected ? 40 : 28, height: isSelected ? 40 : 28)
                .overlay(
                    Text(String(member.name.prefix(2)).uppercased())
                        .font(.system(size: isSelected ? 14 : 10, weight: .bold))
                        .foregroundColor(member.isOnline ? .white : Theme.Colors.robotCream)
                )
                .shadow(color: member.isOnline ? Theme.Colors.connected.opacity(0.5) : .clear, radius: 4)
            
            // Selection ring
            if isSelected {
                Circle()
                    .stroke(Theme.Colors.sunsetOrange, lineWidth: 3)
                    .frame(width: 48, height: 48)
            }
        }
        .position(position)
        .animation(.spring(), value: isSelected)
    }
}

// MARK: - My Location Indicator
struct MyLocationIndicator: View {
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Pulsing ring
            Circle()
                .stroke(Theme.Colors.turquoise.opacity(0.3), lineWidth: 2)
                .frame(width: 40, height: 40)
            
            // Center dot
            Circle()
                .fill(Theme.Colors.turquoise)
                .frame(width: 16, height: 16)
            
            // Inner white dot
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
}

// MARK: - Selected Member Card
struct SelectedMemberCard: View {
    let member: CampMember
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                // Avatar
                Circle()
                    .fill(member.isOnline ? Theme.Colors.connected : Theme.Colors.backgroundLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(member.name.prefix(2)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(member.isOnline ? .white : Theme.Colors.robotCream)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(member.isOnline ? Theme.Colors.connected : Theme.Colors.disconnected)
                            .frame(width: 8, height: 8)
                        Text(member.isOnline ? "Online" : "Offline")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                NavigationLink(destination: CommunityMemberDetailView(member: member)) {
                    HStack {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                
                Button(action: {
                    // TODO: Navigate to member
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Navigate")
                    }
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.turquoise)
                    .cornerRadius(Theme.CornerRadius.md)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Map Legend
struct MapLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Theme.Colors.connected)
                    .frame(width: 10, height: 10)
                Text("Online")
                    .font(Theme.Typography.caption)
            }
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Theme.Colors.backgroundLight)
                    .frame(width: 10, height: 10)
                Text("Offline")
                    .font(Theme.Typography.caption)
            }
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(Theme.Colors.turquoise)
                    .frame(width: 10, height: 10)
                Text("You")
                    .font(Theme.Typography.caption)
            }
        }
        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
        .padding(Theme.Spacing.sm)
        .background(Theme.Colors.backgroundDark.opacity(0.8))
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

#Preview {
    CommunityHubView()
        .environmentObject(MeshtasticManager())
        .environmentObject(ProfileManager())
        .environmentObject(SocialManager())
        .environmentObject(LocationManager())
}
