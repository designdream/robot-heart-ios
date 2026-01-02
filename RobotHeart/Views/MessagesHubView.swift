import SwiftUI

// MARK: - Messages Hub View
/// Unified messaging center: Global Channel + Direct Messages + Announcements
/// Consolidates all communication in one place for better UX
struct MessagesHubView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedSection = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Section picker - just Global and Direct now
                    // Announcements moved to Home where they belong
                    Picker("Section", selection: $selectedSection) {
                        Text("Global").tag(0)
                        Text("Direct").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    // Content
                    TabView(selection: $selectedSection) {
                        // Global Channel - camp-wide chat
                        GlobalChannelView()
                            .tag(0)
                        
                        // Direct Messages - 1:1 conversations
                        DirectMessagesListView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Messages")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
}

// MARK: - Global Channel View
/// Camp-wide chat channel - like a group chat for the whole camp
struct GlobalChannelView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var messageText = ""
    @State private var showingTemplates = false
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Channel header
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Camp Channel")
                        .font(Theme.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("\(meshtasticManager.campMembers.filter { $0.isOnline }.count) online")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.connected)
                }
                
                Spacer()
                
                // Mesh status
                HStack(spacing: 4) {
                    Circle()
                        .fill(meshtasticManager.isConnected ? Theme.Colors.connected : Theme.Colors.disconnected)
                        .frame(width: 8, height: 8)
                    Text(meshtasticManager.isConnected ? "Mesh" : "Offline")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(meshtasticManager.messages) { message in
                            GlobalMessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: meshtasticManager.messages.count) { _ in
                    if let lastMessage = meshtasticManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Quick templates
            if showingTemplates {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(Message.Template.allCases, id: \.self) { template in
                            Button(action: {
                                messageText = template.content
                                showingTemplates = false
                            }) {
                                Text(template.content)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.robotCream)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, Theme.Spacing.xs)
                                    .background(Theme.Colors.backgroundLight)
                                    .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.backgroundMedium.opacity(0.5))
            }
            
            // Input bar
            HStack(spacing: Theme.Spacing.sm) {
                // Templates button
                Button(action: { showingTemplates.toggle() }) {
                    Image(systemName: "text.bubble")
                        .font(.title3)
                        .foregroundColor(showingTemplates ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream.opacity(0.5))
                }
                
                TextField("Message camp...", text: $messageText)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                    .focused($isInputFocused)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
        }
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        meshtasticManager.sendMessage(messageText)
        messageText = ""
    }
}

// MARK: - Global Message Bubble
struct GlobalMessageBubble: View {
    let message: Message
    
    var isFromMe: Bool {
        message.from == "!local" // Local user ID
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if isFromMe { Spacer(minLength: 60) }
            
            if !isFromMe {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Theme.Colors.turquoise.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Text(String(message.fromName.prefix(1)))
                        .font(Theme.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.turquoise)
                }
            }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                if !isFromMe {
                    Text(message.fromName)
                        .font(Theme.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.Colors.turquoise)
                }
                
                Text(message.content)
                    .font(Theme.Typography.body)
                    .foregroundColor(isFromMe ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
                    .padding(Theme.Spacing.sm)
                    .background(isFromMe ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.md)
                
                Text(formatTime(message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            if !isFromMe { Spacer(minLength: 60) }
        }
    }
    
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Direct Messages List View
struct DirectMessagesListView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.sm) {
                // Approved contacts with conversations
                let contactIDs = profileManager.approvedContacts
                
                if contactIDs.isEmpty {
                    EmptyDMsView()
                } else {
                    ForEach(contactIDs, id: \.self) { contactID in
                        if let member = meshtasticManager.campMembers.first(where: { $0.id == contactID }) {
                            NavigationLink(destination: DirectMessageView(member: member)) {
                                DMConversationRowSimple(member: member)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Empty DMs View
struct EmptyDMsView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No conversations yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Connect with people via QR code exchange to start private conversations")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: QRContactExchangeView()) {
                HStack {
                    Image(systemName: "qrcode")
                    Text("Exchange QR Codes")
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

// MARK: - DM Conversation Row Simple
struct DMConversationRowSimple: View {
    let member: CampMember
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.turquoise.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(member.name.prefix(1)))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.turquoise)
                
                // Online indicator
                if member.isOnline {
                    Circle()
                        .fill(Theme.Colors.connected)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Theme.Colors.backgroundDark, lineWidth: 2)
                        )
                        .offset(x: 16, y: 16)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("Tap to message")
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

// MARK: - Announcements Tab View
struct AnnouncementsTabView: View {
    @EnvironmentObject var announcementManager: AnnouncementManager
    @EnvironmentObject var shiftManager: ShiftManager
    @State private var showingCreateSheet = false
    @State private var showingHistory = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Admin create button
            if shiftManager.isAdmin {
                Button(action: { showingCreateSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Announcement")
                    }
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                .padding()
            }
            
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.md) {
                    if announcementManager.announcements.isEmpty {
                        EmptyAnnouncementsPlaceholder()
                    } else {
                        ForEach(announcementManager.announcements) { announcement in
                            AnnouncementListCard(announcement: announcement)
                        }
                    }
                    
                    // History section
                    if !announcementManager.dismissedAnnouncements.isEmpty {
                        Button(action: { showingHistory.toggle() }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("View History (\(announcementManager.dismissedAnnouncements.count))")
                                Spacer()
                                Image(systemName: showingHistory ? "chevron.up" : "chevron.down")
                            }
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            .padding()
                            .background(Theme.Colors.backgroundMedium)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        
                        if showingHistory {
                            ForEach(announcementManager.dismissedAnnouncements) { announcement in
                                AnnouncementListCard(announcement: announcement)
                                    .opacity(0.6)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateAnnouncementView()
                .environmentObject(announcementManager)
        }
    }
}

// MARK: - Empty Announcements Placeholder
struct EmptyAnnouncementsPlaceholder: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "megaphone")
                .font(.system(size: 48))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No announcements")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Official camp announcements will appear here")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.xl)
    }
}

// MARK: - Announcement List Card
struct AnnouncementListCard: View {
    @EnvironmentObject var announcementManager: AnnouncementManager
    let announcement: AnnouncementManager.Announcement
    
    private let currentUserID = "!local"
    
    var isRead: Bool {
        announcement.readBy.contains(currentUserID)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                // Priority indicator
                Image(systemName: announcement.priority.icon)
                    .foregroundColor(priorityColor)
                
                Text(announcement.title)
                    .font(Theme.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text(formatDate(announcement.timestamp))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            Text(announcement.message)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
            
            HStack {
                Text("From: \(announcement.fromName)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                Spacer()
                
                if !isRead {
                    Text("NEW")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(4)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(isRead ? Theme.Colors.backgroundLight : Theme.Colors.sunsetOrange.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(isRead ? Color.clear : Theme.Colors.sunsetOrange.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture {
            announcementManager.markAsRead(announcement)
        }
    }
    
    var priorityColor: Color {
        switch announcement.priority {
        case .urgent: return Theme.Colors.emergency
        case .important: return Theme.Colors.warning
        case .normal: return Theme.Colors.turquoise
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Direct Message View
struct DirectMessageView: View {
    let member: CampMember
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var messageText = ""
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages placeholder
                ScrollView {
                    VStack(spacing: Theme.Spacing.md) {
                        Text("Private conversation with \(member.name)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            .padding(.top, 60)
                    }
                    .padding()
                }
                
                // Input bar
                HStack(spacing: Theme.Spacing.sm) {
                    TextField("Message \(member.name)...", text: $messageText)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.md)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
                    }
                    .disabled(messageText.isEmpty)
                }
                .padding()
                .background(Theme.Colors.backgroundMedium)
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        // TODO: Send direct message via mesh
        messageText = ""
    }
}

#Preview {
    MessagesHubView()
        .environmentObject(MeshtasticManager())
        .environmentObject(AnnouncementManager())
        .environmentObject(ProfileManager())
}
