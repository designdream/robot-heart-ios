import SwiftUI

// MARK: - Home View (Dashboard)
struct HomeView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var emergencyManager: EmergencyManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var checkInManager: CheckInManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var draftManager: DraftManager
    @State private var showingGlobalSearch = false
    @State private var showingQuickActions = false
    @State private var quickActionNavigation: QuickActionDestination?
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // HOME = "What's happening NOW that needs my attention?"
                        // Glanceable dashboard - look once, put phone away
                        
                        // PRIORITY 1: Urgent announcements (action needed)
                        if !announcementManager.announcements.isEmpty {
                            RecentAnnouncementsCard()
                        }
                        
                        // PRIORITY 2: Next commitment with time-to-leave
                        // (Where do I need to be?)
                        NextCommitmentCard()
                        
                        // PRIORITY 3: Safety check-in reminder (only if user opted in)
                        if checkInManager.checkInEnabled {
                            CheckInCard()
                        }
                        
                        // PRIORITY 4: Active draft (time-sensitive)
                        if let draft = draftManager.activeDraft {
                            NavigationLink(destination: LiveDraftView(draft: draft)) {
                                ActiveDraftCard(draft: draft)
                            }
                        }
                        
                        // PRIORITY 5: Connection status (are you connected to mesh?)
                        ConnectionCard()
                        
                        // PRIORITY 6: Upcoming Events (social discovery)
                        UpcomingEventsCard()
                        
                        // NOTE: Social Capital moved to "Me" tab - it's identity, not action
                    }
                    .padding()
                }
                
                // Pull-down quick actions overlay
                PullDownActionsOverlay(isPresented: $showingQuickActions, navigateTo: $quickActionNavigation)
                
                // Hidden navigation links for quick actions
                Group {
                    NavigationLink(tag: .messages, selection: $quickActionNavigation) {
                        DirectMessagesView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .tasks, selection: $quickActionNavigation) {
                        TasksHubView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .commitments, selection: $quickActionNavigation) {
                        MyCommitmentsView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .qrCode, selection: $quickActionNavigation) {
                        QRContactExchangeView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .map, selection: $quickActionNavigation) {
                        MapView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .guide, selection: $quickActionNavigation) {
                        KnowledgeBaseView()
                    } label: { EmptyView() }
                    
                    NavigationLink(tag: .events, selection: $quickActionNavigation) {
                        PlayaEventsView()
                    } label: { EmptyView() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingGlobalSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    // Pull-down trigger in center
                    Button(action: {
                        withAnimation(.spring()) {
                            showingQuickActions.toggle()
                        }
                    }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image("RobotHeartLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 28)
                                .clipShape(Circle())
                            
                            Image(systemName: showingQuickActions ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
                
                // Direct Messages - Most valuable real estate (replaces settings)
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: DirectMessagesView()) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "message.fill")
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            // Unread badge
                            if announcementManager.unreadCount > 0 {
                                Circle()
                                    .fill(Theme.Colors.sunsetOrange)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 2, y: -2)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGlobalSearch) {
                GlobalSearchView()
            }
        }
    }
}

// MARK: - Social Capital Card (replaces Points)
struct SocialCapitalCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Social Capital")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Your trust in the community")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                // Trust level badge
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "heart.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    
                    Text("\(economyManager.myStanding.pointsEarned)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            
            // Trust level progress
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(trustLevelLabel)
                        .font(Theme.Typography.callout)
                        .foregroundColor(trustLevelColor)
                    
                    Spacer()
                    
                    Text("\(economyManager.myStanding.shiftsCompleted) contributions")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                // Progress bar to next level
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.Colors.backgroundLight)
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(trustLevelColor)
                            .frame(width: geometry.size.width * progressToNextLevel, height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    private var trustLevelLabel: String {
        let shifts = economyManager.myStanding.shiftsCompleted
        switch shifts {
        case 20...: return "⭐ Legendary"
        case 10..<20: return "⭐ Superstar"
        case 5..<10: return "✓ Reliable"
        case 3..<5: return "Contributing"
        case 1..<3: return "Improving"
        default: return "New"
        }
    }
    
    private var trustLevelColor: Color {
        let shifts = economyManager.myStanding.shiftsCompleted
        switch shifts {
        case 20...: return Theme.Colors.goldenYellow
        case 10..<20: return Theme.Colors.sunsetOrange
        case 5..<10: return Theme.Colors.connected
        case 3..<5: return Theme.Colors.turquoise
        default: return Theme.Colors.robotCream.opacity(0.5)
        }
    }
    
    private var progressToNextLevel: Double {
        let shifts = economyManager.myStanding.shiftsCompleted
        switch shifts {
        case 20...: return 1.0
        case 10..<20: return Double(shifts - 10) / 10.0
        case 5..<10: return Double(shifts - 5) / 5.0
        case 3..<5: return Double(shifts - 3) / 2.0
        case 1..<3: return Double(shifts - 1) / 2.0
        default: return Double(shifts)
        }
    }
}

// MARK: - Global Search View
struct GlobalSearchView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var campLayoutManager: CampLayoutManager
    @EnvironmentObject var campNetworkManager: CampNetworkManager
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedCategory: SearchCategory = .all
    
    enum SearchCategory: String, CaseIterable {
        case all = "All"
        case people = "People"
        case map = "Map"
        case events = "Events"
        case tasks = "Tasks"
        case camps = "Camps"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.md) {
                    // Search bar with proper styling
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                        
                        TextField("Search people, events, tasks, camps...", text: $searchText)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream)
                            .autocapitalization(.none)
                            .tint(Theme.Colors.sunsetOrange)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm + 4)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(Theme.Colors.robotCream.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal, Theme.Spacing.md)
                    
                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(SearchCategory.allCases, id: \.self) { category in
                                SearchCategoryPill(
                                    title: category.rawValue,
                                    isSelected: selectedCategory == category
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                    }
                    
                    // Results
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            if searchText.isEmpty {
                                recentSearchesView
                            } else {
                                searchResultsView
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                        .padding(.bottom, Theme.Spacing.xl)
                    }
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    private var recentSearchesView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Quick Access Section
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("QUICK ACCESS")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
                
                HStack(spacing: Theme.Spacing.md) {
                    QuickSearchButton(icon: "person.3.fill", title: "Roster") {
                        // Navigate to roster
                    }
                    QuickSearchButton(icon: "calendar", title: "Events") {
                        // Navigate to events
                    }
                    QuickSearchButton(icon: "mappin.circle.fill", title: "Map") {
                        // Navigate to map
                    }
                }
            }
            
            // Divider with proper spacing
            Rectangle()
                .fill(Theme.Colors.robotCream.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, Theme.Spacing.xs)
            
            // Nearby Camps Section
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("NEARBY CAMPS")
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .tracking(0.5)
                
                Text("Connect to mesh network to discover nearby camps")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .padding(Theme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // People results
            if selectedCategory == .all || selectedCategory == .people {
                let peopleResults = meshtasticManager.campMembers.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
                if !peopleResults.isEmpty {
                    SearchResultSection(title: "People", count: peopleResults.count) {
                        ForEach(peopleResults) { member in
                            SearchResultRow(
                                icon: "person.fill",
                                title: member.name,
                                subtitle: member.role.rawValue,
                                color: Theme.Colors.turquoise
                            )
                        }
                    }
                }
            }
            
            // Map items results (from our camp layout - privacy respected)
            if selectedCategory == .all || selectedCategory == .map {
                let mapItemResults = mapSearchResults
                if !mapItemResults.isEmpty {
                    SearchResultSection(title: "Map Items", count: mapItemResults.count) {
                        ForEach(mapItemResults) { item in
                            MapSearchResultRow(item: item)
                        }
                    }
                }
                
                // Members with shared locations (only from our camp)
                let locationResults = membersWithLocations
                if !locationResults.isEmpty {
                    SearchResultSection(title: "Member Locations", count: locationResults.count) {
                        ForEach(locationResults) { member in
                            SearchResultRow(
                                icon: "mappin.circle.fill",
                                title: member.name,
                                subtitle: member.lastKnownLocation ?? "Location shared",
                                color: Theme.Colors.turquoise
                            )
                        }
                    }
                }
            }
            
            // Tasks results
            if selectedCategory == .all || selectedCategory == .tasks {
                let taskResults = taskManager.tasks.filter {
                    $0.title.localizedCaseInsensitiveContains(searchText)
                }
                if !taskResults.isEmpty {
                    SearchResultSection(title: "Tasks", count: taskResults.count) {
                        ForEach(taskResults) { task in
                            SearchResultRow(
                                icon: "checkmark.circle",
                                title: task.title,
                                subtitle: task.priority.shortLabel,
                                color: Theme.Colors.sunsetOrange
                            )
                        }
                    }
                }
            }
            
            // Events results
            if selectedCategory == .all || selectedCategory == .events {
                let eventResults = socialManager.playaEvents.filter {
                    $0.title.localizedCaseInsensitiveContains(searchText)
                }
                if !eventResults.isEmpty {
                    SearchResultSection(title: "Events", count: eventResults.count) {
                        ForEach(eventResults) { event in
                            SearchResultRow(
                                icon: "calendar",
                                title: event.title,
                                subtitle: event.location.displayText,
                                color: Theme.Colors.goldenYellow
                            )
                        }
                    }
                }
            }
            
            // Camps results (discovered camps via mesh)
            if selectedCategory == .all || selectedCategory == .camps {
                let campResults = campSearchResults
                if !campResults.isEmpty {
                    SearchResultSection(title: "Camps", count: campResults.count) {
                        ForEach(campResults) { camp in
                            CampSearchResultRow(camp: camp, isOurCamp: camp.id == campNetworkManager.myCamp?.id.uuidString)
                        }
                    }
                }
            }
            
            // No results
            if searchResultsEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                    Text("No results for \"\(searchText)\"")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    Text("Try searching for people, events, tasks, map items, or camps")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }
    
    // MARK: - Map Search Results (Privacy-Aware)
    
    /// Search camp layout items - only from camps user belongs to
    private var mapSearchResults: [PlaceableItem] {
        guard let layout = campLayoutManager.currentLayout else { return [] }
        
        return layout.items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
            (item.assignedName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    /// Members who have shared their location (respects ghost mode)
    private var membersWithLocations: [CampMember] {
        meshtasticManager.campMembers.filter { member in
            member.name.localizedCaseInsensitiveContains(searchText) &&
            member.lastKnownLocation != nil &&
            !member.isGhostMode
        }
    }
    
    /// Search discovered camps
    private var campSearchResults: [DiscoveredCamp] {
        var results: [DiscoveredCamp] = []
        
        // Add our camp if it matches
        if let myCamp = campNetworkManager.myCamp,
           myCamp.name.localizedCaseInsensitiveContains(searchText) ||
           myCamp.location.localizedCaseInsensitiveContains(searchText) {
            results.append(DiscoveredCamp(
                id: myCamp.id.uuidString,
                name: myCamp.name,
                location: myCamp.location,
                memberCount: myCamp.memberCount,
                description: myCamp.description,
                lastSeen: Date(),
                signalStrength: 100
            ))
        }
        
        // Add discovered camps that match
        results.append(contentsOf: campNetworkManager.discoveredCamps.filter { camp in
            camp.name.localizedCaseInsensitiveContains(searchText) ||
            camp.location.localizedCaseInsensitiveContains(searchText)
        })
        
        return results
    }
    
    private var searchResultsEmpty: Bool {
        let people = meshtasticManager.campMembers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        let tasks = taskManager.tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        let events = socialManager.playaEvents.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        let mapItems = mapSearchResults
        let locations = membersWithLocations
        let camps = campSearchResults
        
        switch selectedCategory {
        case .all: return people.isEmpty && tasks.isEmpty && events.isEmpty && mapItems.isEmpty && locations.isEmpty && camps.isEmpty
        case .people: return people.isEmpty
        case .map: return mapItems.isEmpty && locations.isEmpty
        case .tasks: return tasks.isEmpty
        case .events: return events.isEmpty
        case .camps: return camps.isEmpty
        }
    }
}

// MARK: - Map Search Result Row
struct MapSearchResultRow: View {
    let item: PlaceableItem
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Item type icon
            Image(systemName: item.type.icon)
                .font(.title3)
                .foregroundColor(item.swiftUIColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.sm) {
                    Text(item.type.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    
                    if let assignee = item.assignedName {
                        Text("•")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                        Text(assignee)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                }
            }
            
            Spacer()
            
            // Size info
            Text("\(Int(item.widthFeet))×\(Int(item.depthFeet))'")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Camp Search Result Row
struct CampSearchResultRow: View {
    let camp: DiscoveredCamp
    let isOurCamp: Bool
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Camp icon
            ZStack {
                Circle()
                    .fill(isOurCamp ? Theme.Colors.sunsetOrange.opacity(0.2) : Theme.Colors.turquoise.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: isOurCamp ? "house.fill" : "tent.fill")
                    .font(.system(size: 18))
                    .foregroundColor(isOurCamp ? Theme.Colors.sunsetOrange : Theme.Colors.turquoise)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(camp.name)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if isOurCamp {
                        Text("(Your Camp)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
                
                HStack(spacing: Theme.Spacing.sm) {
                    Label(camp.location, systemImage: "mappin")
                    Label("\(camp.memberCount)", systemImage: "person.2")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            // Signal strength for discovered camps
            if !isOurCamp {
                SignalStrengthIndicator(strength: camp.signalStrength)
            }
        }
        .padding()
        .background(isOurCamp ? Theme.Colors.sunsetOrange.opacity(0.1) : Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(isOurCamp ? Theme.Colors.sunsetOrange.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Signal Strength Indicator
struct SignalStrengthIndicator: View {
    let strength: Int // 0-100
    
    var bars: Int {
        switch strength {
        case 75...100: return 4
        case 50..<75: return 3
        case 25..<50: return 2
        default: return 1
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(index < bars ? Theme.Colors.connected : Theme.Colors.robotCream.opacity(0.2))
                    .frame(width: 4, height: CGFloat(6 + index * 3))
            }
        }
    }
}

// MARK: - Search Category Pill
struct SearchCategoryPill: View {
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
                .background(isSelected ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.sm)
        }
    }
}

// MARK: - Quick Search Button
struct QuickSearchButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(Theme.Colors.robotCream)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Search Result Section
struct SearchResultSection<Content: View>: View {
    let title: String
    let count: Int
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(title.uppercased())
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                Text("(\(count))")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            }
            
            content
        }
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                Text(subtitle)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Connection Card
struct ConnectionCard: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        HStack {
            Circle()
                .fill(meshtasticManager.isConnected ? Theme.Colors.connected : Theme.Colors.disconnected)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(meshtasticManager.isConnected ? "Connected" : "Disconnected")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                if let device = meshtasticManager.connectedDevice {
                    Text(device)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
            }
            
            Spacer()
            
            if !meshtasticManager.isConnected {
                Button("Connect") {
                    meshtasticManager.startScanning()
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.sm)
            } else {
                Text("\(meshtasticManager.campMembers.filter { $0.isOnline }.count) online")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.connected)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Active Draft Card
struct ActiveDraftCard: View {
    @EnvironmentObject var draftManager: DraftManager
    let draft: ShiftDraft
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(Theme.Colors.connected)
                
                Text("Draft In Progress")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                if draftManager.isMyTurn {
                    Text("YOUR PICK!")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.full)
                }
            }
            
            Text(draft.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
            
            HStack {
                Text("Round \(draft.currentRound)/\(draft.totalRounds)")
                Spacer()
                Text("\(draft.remainingShifts.count) shifts left")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(Theme.Colors.connected, lineWidth: 2)
        )
    }
}

// MARK: - Next Commitment Card (Time-to-leave focused)
struct NextCommitmentCard: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var taskManager: TaskManager
    
    // Playa bike speed limit is 5 mph (~2.2 m/s)
    private let playaBikeSpeedMPS: Double = 2.2
    
    var nextShift: Shift? {
        shiftManager.myShifts
            .filter { $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
            .first
    }
    
    var timeUntilShift: TimeInterval? {
        guard let shift = nextShift else { return nil }
        return shift.startTime.timeIntervalSince(Date())
    }
    
    var leaveStatus: (message: String, color: Color, icon: String)? {
        guard let interval = timeUntilShift else { return nil }
        let minutes = Int(interval / 60)
        
        // Assume 10 min travel + 5 min buffer
        let leaveInMinutes = minutes - 15
        
        if leaveInMinutes < 0 {
            return ("You should have left \(abs(leaveInMinutes)) min ago!", Theme.Colors.emergency, "exclamationmark.triangle.fill")
        } else if leaveInMinutes < 5 {
            return ("Leave now to be on time", Theme.Colors.sunsetOrange, "figure.walk")
        } else if leaveInMinutes < 15 {
            return ("Leave in \(leaveInMinutes) min", Theme.Colors.goldenYellow, "clock.fill")
        } else if leaveInMinutes < 60 {
            return ("\(leaveInMinutes) min until you need to leave", Theme.Colors.connected, "checkmark.circle")
        } else {
            let hours = leaveInMinutes / 60
            let mins = leaveInMinutes % 60
            return ("\(hours)h \(mins)m until you need to leave", Theme.Colors.robotCream.opacity(0.5), "clock")
        }
    }
    
    var body: some View {
        if let shift = nextShift, let status = leaveStatus {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("NEXT COMMITMENT")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    Spacer()
                    
                    NavigationLink(destination: ShiftsView()) {
                        Text("My Burn →")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
                
                HStack(spacing: Theme.Spacing.md) {
                    // Shift icon
                    Image(systemName: shift.location.icon)
                        .font(.title2)
                        .foregroundColor(Theme.Colors.turquoise)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.turquoise.opacity(0.15))
                        .cornerRadius(Theme.CornerRadius.md)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shift.location.rawValue)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text(formatTime(shift.startTime))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                    
                    Spacer()
                }
                
                // Time to leave indicator
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: status.icon)
                        .font(.system(size: 14))
                        .foregroundColor(status.color)
                    
                    Text(status.message)
                        .font(Theme.Typography.callout)
                        .fontWeight(status.color == Theme.Colors.emergency || status.color == Theme.Colors.sunsetOrange ? .semibold : .regular)
                        .foregroundColor(status.color)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(status.color.opacity(0.1))
                .cornerRadius(Theme.CornerRadius.md)
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.lg)
        } else {
            // No upcoming commitments
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack {
                    Text("NEXT COMMITMENT")
                        .font(Theme.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        .tracking(0.5)
                    
                    Spacer()
                    
                    NavigationLink(destination: ShiftsView()) {
                        Text("Find ways to contribute →")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
                
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(Theme.Colors.connected)
                    Text("You're free! Enjoy the playa.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                .padding()
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.lg)
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - My Upcoming Shifts Card
struct MyUpcomingShiftsCard: View {
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("My Shifts")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                NavigationLink(destination: ShiftBlockHubView()) {
                    Text("See All")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            
            if shiftBlockManager.myUpcomingShifts.isEmpty {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                    Text("No upcoming shifts")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                .padding()
            } else {
                ForEach(shiftBlockManager.myUpcomingShifts.prefix(2)) { block in
                    HStack {
                        Image(systemName: block.location.icon)
                            .foregroundColor(Theme.Colors.turquoise)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(block.location.rawValue)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Text(block.dayText)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                        
                        Spacer()
                        
                        Text(block.timeRangeText)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.sm)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Points Summary Card
struct PointsSummaryCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        NavigationLink(destination: EconomyDashboardView()) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Points")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(economyManager.myStanding.pointsEarned)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        
                        Text("/ \(economyManager.myStanding.pointsRequired)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                Spacer()
                
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.backgroundLight, lineWidth: 6)
                        .frame(width: 50, height: 50)
                    
                    Circle()
                        .trim(from: 0, to: economyManager.myStanding.completionPercentage)
                        .stroke(Theme.Colors.sunsetOrange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(economyManager.myStanding.completionPercentage * 100))%")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Quick Actions Grid
struct QuickActionsGrid: View {
    @EnvironmentObject var emergencyManager: EmergencyManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Quick Actions")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: Theme.Spacing.sm) {
                // ROW 1: Most used daily actions
                NavigationLink(destination: TasksHubView()) {
                    QuickActionTile(icon: "checklist", title: "Tasks", color: Theme.Colors.sunsetOrange)
                }
                
                NavigationLink(destination: RosterView()) {
                    QuickActionTile(icon: "person.3.fill", title: "Roster", color: Theme.Colors.dustyPink)
                }
                
                NavigationLink(destination: MapView()) {
                    QuickActionTile(icon: "location.fill", title: "Playa Map", color: Theme.Colors.turquoise)
                }
                
                // ROW 2: Camp operations & resources
                NavigationLink(destination: PlayaEventsView()) {
                    QuickActionTile(icon: "calendar.badge.plus", title: "Events", color: Theme.Colors.dustyPink)
                }
                
                NavigationLink(destination: KnowledgeBaseView()) {
                    QuickActionTile(icon: "book.fill", title: "Guide", color: Theme.Colors.goldenYellow)
                }
                
                NavigationLink(destination: QRContactExchangeView()) {
                    QuickActionTile(icon: "qrcode", title: "Connect", color: Theme.Colors.turquoise)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Quick Action Tile
struct QuickActionTile: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
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
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Recent Announcements Card
struct RecentAnnouncementsCard: View {
    @EnvironmentObject var announcementManager: AnnouncementManager
    
    var hasUrgent: Bool {
        announcementManager.announcements.contains { $0.priority == .urgent }
    }
    
    var hasImportant: Bool {
        announcementManager.announcements.contains { $0.priority == .important }
    }
    
    var iconColor: Color {
        if hasUrgent { return Theme.Colors.emergency }
        if hasImportant { return Theme.Colors.warning }
        return Theme.Colors.goldenYellow
    }
    
    var body: some View {
        NavigationLink(destination: AnnouncementsListView()) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                AnnouncementCardHeader(
                    iconColor: iconColor,
                    unreadCount: announcementManager.unreadCount,
                    hasUrgent: hasUrgent
                )
                
                ForEach(announcementManager.announcements.prefix(3)) { announcement in
                    AnnouncementRow(announcement: announcement)
                }
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(hasUrgent ? Theme.Colors.emergency : (hasImportant ? Theme.Colors.warning : Color.clear), lineWidth: 2)
            )
        }
    }
}

// MARK: - Announcement Card Header
struct AnnouncementCardHeader: View {
    let iconColor: Color
    let unreadCount: Int
    let hasUrgent: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "megaphone.fill")
                .foregroundColor(iconColor)
            
            Text("Announcements")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
            
            if unreadCount > 0 {
                Text("\(unreadCount) new")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(hasUrgent ? Theme.Colors.emergency : Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.full)
            }
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
    }
}

// MARK: - Announcement Row
struct AnnouncementRow: View {
    let announcement: AnnouncementManager.Announcement
    private let currentUserID = "!local"
    
    var priorityColor: Color {
        switch announcement.priority {
        case .normal: return Theme.Colors.turquoise
        case .important: return Theme.Colors.warning
        case .urgent: return Theme.Colors.emergency
        }
    }
    
    var backgroundColor: Color {
        announcement.priority == .urgent ? Theme.Colors.emergency.opacity(0.1) : Theme.Colors.backgroundLight
    }
    
    var isUnread: Bool {
        !announcement.readBy.contains(currentUserID)
    }
    
    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            RoundedRectangle(cornerRadius: 2)
                .fill(priorityColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(announcement.title)
                        .font(Theme.Typography.body)
                        .fontWeight(announcement.priority == .urgent ? .bold : .regular)
                        .foregroundColor(Theme.Colors.robotCream)
                        .lineLimit(1)
                    
                    if isUnread {
                        Circle()
                            .fill(Theme.Colors.sunsetOrange)
                            .frame(width: 6, height: 6)
                    }
                }
                
                Text(announcement.message)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    .lineLimit(2)
                
                Text(timeAgo(announcement.timestamp))
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            Spacer()
        }
        .padding(Theme.Spacing.sm)
        .background(backgroundColor)
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Upcoming Events Card
struct UpcomingEventsCard: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(Theme.Colors.dustyPink)
                
                Text("Upcoming Events")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                NavigationLink(destination: PlayaEventsView()) {
                    Text("See All")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            
            let events = Array(socialManager.upcomingEvents.prefix(3))
            
            if events.isEmpty {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                    Text("No upcoming events")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                .padding()
            } else {
                ForEach(events) { event in
                    NavigationLink(destination: PlayaEventsView()) {
                        HStack {
                            Image(systemName: event.category.icon)
                                .foregroundColor(event.category.color)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(Theme.Typography.callout)
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.Colors.robotCream)
                                
                                Text(formatEventTime(event.startTime))
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            }
                            
                            Spacer()
                            
                            if !event.attendees.isEmpty {
                                Text("\(event.attendees.count) going")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.connected)
                            }
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.sm)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    func formatEventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, h:mm a"
        return formatter.string(from: date)
    }
}

#Preview {
    HomeView()
        .environmentObject(MeshtasticManager())
        .environmentObject(ShiftBlockManager())
        .environmentObject(EconomyManager())
        .environmentObject(EmergencyManager())
        .environmentObject(AnnouncementManager())
        .environmentObject(CheckInManager())
        .environmentObject(ProfileManager())
        .environmentObject(DraftManager())
        .environmentObject(ShiftManager())
        .environmentObject(SocialManager())
}
