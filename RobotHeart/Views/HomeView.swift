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
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Connection status
                        ConnectionCard()
                        
                        // Safety check-in
                        CheckInCard()
                        
                        // Active draft banner
                        if let draft = draftManager.activeDraft {
                            NavigationLink(destination: LiveDraftView(draft: draft)) {
                                ActiveDraftCard(draft: draft)
                            }
                        }
                        
                        // My upcoming shifts
                        MyUpcomingShiftsCard()
                        
                        // Points summary
                        PointsSummaryCard()
                        
                        // Quick actions grid
                        QuickActionsGrid()
                        
                        // Recent announcements
                        if !announcementManager.announcements.isEmpty {
                            RecentAnnouncementsCard()
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Image("RobotHeartLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 32)
                            .clipShape(Circle())
                        Text("Robot Heart")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
            }
        }
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
                NavigationLink(destination: DraftHubView()) {
                    QuickActionTile(icon: "sportscourt", title: "Draft", color: Theme.Colors.turquoise)
                }
                
                NavigationLink(destination: CampMapView()) {
                    QuickActionTile(icon: "map.fill", title: "Camp Map", color: Theme.Colors.connected)
                }
                
                NavigationLink(destination: AnnouncementsListView()) {
                    QuickActionTile(icon: "megaphone.fill", title: "Announce", color: Theme.Colors.goldenYellow)
                }
                
                NavigationLink(destination: RosterView()) {
                    QuickActionTile(icon: "person.3.fill", title: "Roster", color: Theme.Colors.dustyPink)
                }
                
                NavigationLink(destination: MapView()) {
                    QuickActionTile(icon: "location.fill", title: "Playa Map", color: Theme.Colors.turquoise)
                }
                
                NavigationLink(destination: PlayaEventsView()) {
                    QuickActionTile(icon: "calendar.badge.plus", title: "Events", color: Theme.Colors.dustyPink)
                }
                
                NavigationLink(destination: KnowledgeBaseView()) {
                    QuickActionTile(icon: "book.fill", title: "Guide", color: Theme.Colors.goldenYellow)
                }
                
                NavigationLink(destination: QRContactExchangeView()) {
                    QuickActionTile(icon: "qrcode", title: "Connect", color: Theme.Colors.turquoise)
                }
                
                NavigationLink(destination: TasksHubView()) {
                    QuickActionTile(icon: "checklist", title: "Tasks", color: Theme.Colors.sunsetOrange)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Announcements")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                if announcementManager.unreadCount > 0 {
                    Text("\(announcementManager.unreadCount) new")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.full)
                }
            }
            
            ForEach(announcementManager.announcements.prefix(2)) { announcement in
                HStack {
                    Image(systemName: priorityIcon(announcement.priority))
                        .foregroundColor(priorityColor(announcement.priority))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(announcement.title)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream)
                            .lineLimit(1)
                        
                        Text(announcement.message)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.sm)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
    
    private func priorityIcon(_ priority: AnnouncementManager.Announcement.Priority) -> String {
        switch priority {
        case .normal: return "info.circle"
        case .important: return "exclamationmark.circle"
        case .urgent: return "exclamationmark.triangle.fill"
        }
    }
    
    private func priorityColor(_ priority: AnnouncementManager.Announcement.Priority) -> Color {
        switch priority {
        case .normal: return Theme.Colors.turquoise
        case .important: return Theme.Colors.warning
        case .urgent: return Theme.Colors.emergency
        }
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
}
