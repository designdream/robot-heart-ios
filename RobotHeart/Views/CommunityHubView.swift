import SwiftUI

// MARK: - Community Hub View
/// THE CORE of the Burning Man experience: Human Connection
/// Research shows this is the #1 reason people participate in Burning Man
/// "Real connection with humans... relating to people face to face, eye contact, hugs"
struct CommunityHubView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var searchText = ""
    @State private var selectedFilter: CommunityFilter = .all
    
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
                    // Connection status header
                    ConnectionStatusHeader(
                        totalMembers: meshtasticManager.campMembers.count,
                        onlineCount: onlineCount,
                        myConnectionsCount: profileManager.approvedContacts.count
                    )
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        TextField("Find someone...", text: $searchText)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    
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
                            // Prompt to connect
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Community")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: PlacesView()) {
                        Image(systemName: "map.fill")
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                }
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
    
    var isConnection: Bool {
        profileManager.approvedContacts.contains(member.id)
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
                HStack {
                    Text(member.name)
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if isConnection {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.dustyPink)
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

#Preview {
    CommunityHubView()
        .environmentObject(MeshtasticManager())
        .environmentObject(ProfileManager())
        .environmentObject(SocialManager())
}
