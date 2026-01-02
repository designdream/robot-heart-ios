import SwiftUI

// MARK: - Announcement Banner
struct AnnouncementBanner: View {
    let announcement: AnnouncementManager.Announcement
    let onDismiss: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: announcement.priority.icon)
                    .font(.title3)
                    .foregroundColor(priorityColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(announcement.title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                    
                    Text(announcement.message)
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(Theme.Spacing.md)
            .background(priorityColor)
        }
        .onTapGesture(perform: onTap)
    }
    
    private var priorityColor: Color {
        switch announcement.priority {
        case .normal: return Theme.Colors.turquoise
        case .important: return Theme.Colors.sunsetOrange
        case .urgent: return Theme.Colors.emergency
        }
    }
}

// MARK: - Announcements List View
struct AnnouncementsListView: View {
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var shiftManager: ShiftManager
    @State private var showingCreateSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        if announcementManager.activeAnnouncements.isEmpty {
                            EmptyAnnouncementsView()
                        } else {
                            ForEach(announcementManager.activeAnnouncements) { announcement in
                                AnnouncementCard(announcement: announcement)
                                    .onTapGesture {
                                        announcementManager.markAsRead(announcement)
                                    }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if shiftManager.isAdmin {
                        Button(action: { showingCreateSheet = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if announcementManager.unreadCount > 0 {
                        Button("Mark All Read") {
                            announcementManager.markAllAsRead()
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.turquoise)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateAnnouncementView()
                    .environmentObject(announcementManager)
            }
        }
    }
}

// MARK: - Announcement Card
struct AnnouncementCard: View {
    let announcement: AnnouncementManager.Announcement
    @EnvironmentObject var announcementManager: AnnouncementManager
    
    private var isUnread: Bool {
        !announcement.readBy.contains("!local")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: announcement.priority.icon)
                    .foregroundColor(priorityColor)
                
                Text(announcement.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                if isUnread {
                    Circle()
                        .fill(Theme.Colors.sunsetOrange)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(announcement.message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
            
            HStack {
                Text("From \(announcement.fromName)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                Spacer()
                
                Text(announcement.timeAgoText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding(Theme.Spacing.md)
        .background(isUnread ? Theme.Colors.backgroundLight : Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(priorityColor.opacity(isUnread ? 0.5 : 0), lineWidth: 1)
        )
    }
    
    private var priorityColor: Color {
        switch announcement.priority {
        case .normal: return Theme.Colors.turquoise
        case .important: return Theme.Colors.sunsetOrange
        case .urgent: return Theme.Colors.emergency
        }
    }
}

// MARK: - Create Announcement View
struct CreateAnnouncementView: View {
    @EnvironmentObject var announcementManager: AnnouncementManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var message = ""
    @State private var priority: AnnouncementManager.Announcement.Priority = .normal
    @State private var expiresIn: ExpirationOption = .never
    
    enum ExpirationOption: String, CaseIterable {
        case never = "Never"
        case oneHour = "1 Hour"
        case fourHours = "4 Hours"
        case oneDay = "1 Day"
        
        var interval: TimeInterval? {
            switch self {
            case .never: return nil
            case .oneHour: return 3600
            case .fourHours: return 14400
            case .oneDay: return 86400
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Title", text: $title)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        TextField("Message", text: $message, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Content")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        Picker("Priority", selection: $priority) {
                            ForEach(AnnouncementManager.Announcement.Priority.allCases, id: \.self) { p in
                                HStack {
                                    Image(systemName: p.icon)
                                    Text(p.rawValue)
                                }
                                .tag(p)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        Picker("Expires", selection: $expiresIn) {
                            ForEach(ExpirationOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Options")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Quick templates
                    Section {
                        ForEach(QuickTemplate.allCases, id: \.self) { template in
                            Button(action: {
                                title = template.title
                                message = template.message
                                priority = template.priority
                            }) {
                                HStack {
                                    Image(systemName: template.icon)
                                        .foregroundColor(Theme.Colors.turquoise)
                                    Text(template.title)
                                        .foregroundColor(Theme.Colors.robotCream)
                                }
                            }
                        }
                    } header: {
                        Text("Quick Templates")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Announcement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendAnnouncement()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(title.isEmpty || message.isEmpty)
                }
            }
        }
    }
    
    private func sendAnnouncement() {
        announcementManager.sendAnnouncement(
            title: title,
            message: message,
            priority: priority,
            expiresIn: expiresIn.interval
        )
        dismiss()
    }
    
    enum QuickTemplate: CaseIterable {
        case artCarLeaving
        case iceAvailable
        case shiftChange
        case whiteout
        case meetUp
        
        var title: String {
            switch self {
            case .artCarLeaving: return "Art Car Leaving"
            case .iceAvailable: return "Ice Available"
            case .shiftChange: return "Shift Change"
            case .whiteout: return "Weather Alert"
            case .meetUp: return "Meet Up"
            }
        }
        
        var message: String {
            switch self {
            case .artCarLeaving: return "Robot Heart bus leaving in 30 minutes. Meet at camp entrance."
            case .iceAvailable: return "Fresh ice available at camp. Come grab some!"
            case .shiftChange: return "Shift change happening now. Please check your schedule."
            case .whiteout: return "Whiteout conditions - stay where you are until it clears."
            case .meetUp: return "Meet at the heart in 15 minutes."
            }
        }
        
        var priority: AnnouncementManager.Announcement.Priority {
            switch self {
            case .whiteout: return .urgent
            case .artCarLeaving, .shiftChange: return .important
            default: return .normal
            }
        }
        
        var icon: String {
            switch self {
            case .artCarLeaving: return "bus.fill"
            case .iceAvailable: return "snowflake"
            case .shiftChange: return "clock.fill"
            case .whiteout: return "cloud.fog.fill"
            case .meetUp: return "person.3.fill"
            }
        }
    }
}

// MARK: - Empty Announcements View
struct EmptyAnnouncementsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "megaphone")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Announcements")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Camp announcements will appear here")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .padding(Theme.Spacing.xl)
    }
}

#Preview {
    AnnouncementsListView()
        .environmentObject(AnnouncementManager())
        .environmentObject(ShiftManager())
}
