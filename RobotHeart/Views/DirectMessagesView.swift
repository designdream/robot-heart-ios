import SwiftUI

// MARK: - Direct Messages View
/// Main view for person-to-person messaging.
/// Shows conversation list and allows starting new conversations.

struct DirectMessagesView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var localDataManager: LocalDataManager
    @State private var showingNewConversation = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        TextField("Search conversations...", text: $searchText)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    
                    if conversations.isEmpty {
                        // Empty state
                        emptyStateView
                    } else {
                        // Conversation list
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(filteredConversations) { conversation in
                                    NavigationLink(destination: ConversationView(conversation: conversation)) {
                                        ConversationRow(conversation: conversation)
                                    }
                                    
                                    Divider()
                                        .background(Theme.Colors.robotCream.opacity(0.1))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewConversation = true }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            .sheet(isPresented: $showingNewConversation) {
                NewConversationView()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var conversations: [Conversation] {
        // Group messages by conversation partner
        var convos: [String: Conversation] = [:]
        let myID = UserDefaults.standard.string(forKey: "userID") ?? ""
        
        for message in localDataManager.messages {
            guard let senderID = message.senderID,
                  let recipientID = message.recipientID,
                  recipientID != "broadcast" else { continue }
            
            // Determine the other party
            let partnerID = senderID == myID ? recipientID : senderID
            let partnerName = senderID == myID ? (message.recipientID ?? "Unknown") : (message.senderName ?? "Unknown")
            
            if var existing = convos[partnerID] {
                existing.messages.append(message)
                if let timestamp = message.timestamp, timestamp > (existing.lastMessageTime ?? Date.distantPast) {
                    existing.lastMessageTime = timestamp
                    existing.lastMessagePreview = message.content ?? ""
                }
                convos[partnerID] = existing
            } else {
                convos[partnerID] = Conversation(
                    id: partnerID,
                    partnerID: partnerID,
                    partnerName: partnerName,
                    messages: [message],
                    lastMessageTime: message.timestamp,
                    lastMessagePreview: message.content ?? "",
                    unreadCount: message.isRead ? 0 : 1
                )
            }
        }
        
        // Also add camp members who we haven't messaged yet
        for member in meshtasticManager.campMembers {
            if convos[member.id] == nil {
                convos[member.id] = Conversation(
                    id: member.id,
                    partnerID: member.id,
                    partnerName: member.name,
                    messages: [],
                    lastMessageTime: nil,
                    lastMessagePreview: "Start a conversation",
                    unreadCount: 0
                )
            }
        }
        
        return convos.values.sorted { ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast) }
    }
    
    private var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversations
        }
        return conversations.filter { $0.partnerName.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Conversations Yet")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Start a conversation with a camp member")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            
            Button(action: { showingNewConversation = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text("New Message")
                }
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            Spacer()
        }
    }
}

// MARK: - Conversation Model

struct Conversation: Identifiable {
    let id: String
    let partnerID: String
    var partnerName: String
    var messages: [CachedMessage]
    var lastMessageTime: Date?
    var lastMessagePreview: String
    var unreadCount: Int
    
    var hasMessages: Bool {
        !messages.isEmpty
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: Conversation
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.Colors.turquoise.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(conversation.partnerName.prefix(1).uppercased())
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.turquoise)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.partnerName)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                        .fontWeight(conversation.unreadCount > 0 ? .bold : .regular)
                    
                    Spacer()
                    
                    if let time = conversation.lastMessageTime {
                        Text(timeAgo(time))
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                
                HStack {
                    Text(conversation.lastMessagePreview)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Theme.Colors.sunsetOrange)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding()
        .background(conversation.unreadCount > 0 ? Theme.Colors.sunsetOrange.opacity(0.05) : Color.clear)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

// MARK: - Conversation View (Chat)

struct ConversationView: View {
    let conversation: Conversation
    @EnvironmentObject var localDataManager: LocalDataManager
    @State private var messageText = ""
    @State private var messages: [CachedMessage] = []
    @FocusState private var isInputFocused: Bool
    
    private let myID = UserDefaults.standard.string(forKey: "userID") ?? ""
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(sortedMessages, id: \.id) { message in
                                DMMessageBubble(
                                    message: message,
                                    isFromMe: message.senderID == myID
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastID = sortedMessages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // Input bar
                inputBar
            }
        }
        .navigationTitle(conversation.partnerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMessages()
        }
    }
    
    private var sortedMessages: [CachedMessage] {
        messages.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }
    
    private var inputBar: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Text field
            TextField("Message...", text: $messageText)
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.backgroundLight)
                .cornerRadius(Theme.CornerRadius.lg)
                .foregroundColor(Theme.Colors.robotCream)
                .focused($isInputFocused)
            
            // Send button
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(messageText.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
    
    private func loadMessages() {
        messages = localDataManager.fetchMessages(with: conversation.partnerID)
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Me"
        
        // Save message locally
        let newMessage = localDataManager.saveMessage(
            senderID: myID,
            senderName: userName,
            recipientID: conversation.partnerID,
            content: messageText,
            messageType: "text"
        )
        
        // Add to local list
        messages.append(newMessage)
        
        // Send via mesh
        MessageQueueManager.shared.sendMessage(
            to: conversation.partnerID,
            content: messageText,
            messageType: .text
        )
        
        // Clear input
        messageText = ""
    }
}

// MARK: - DM Message Bubble

struct DMMessageBubble: View {
    let message: CachedMessage
    let isFromMe: Bool
    
    var body: some View {
        HStack {
            if isFromMe { Spacer() }
            
            VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
                // Content
                Text(message.content ?? "")
                    .font(Theme.Typography.body)
                    .foregroundColor(isFromMe ? .white : Theme.Colors.robotCream)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(isFromMe ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
                    .cornerRadius(Theme.CornerRadius.lg)
                
                // Timestamp and status
                HStack(spacing: 4) {
                    if let timestamp = message.timestamp {
                        Text(formatTime(timestamp))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                    }
                    
                    if isFromMe {
                        Image(systemName: message.isDelivered ? "checkmark.circle.fill" : "clock")
                            .font(.system(size: 10))
                            .foregroundColor(message.isDelivered ? Theme.Colors.connected : Theme.Colors.robotCream.opacity(0.4))
                    }
                }
            }
            
            if !isFromMe { Spacer() }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - New Conversation View

struct NewConversationView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var selectedMember: CampMember?
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        
                        TextField("Search by playa name...", text: $searchText)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    
                    // Member list
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredMembers) { member in
                                Button(action: { selectMember(member) }) {
                                    DMMemberSelectRow(member: member)
                                }
                                
                                Divider()
                                    .background(Theme.Colors.robotCream.opacity(0.1))
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
            .background(
                NavigationLink(
                    destination: selectedMember.map { member in
                        ConversationView(conversation: Conversation(
                            id: member.id,
                            partnerID: member.id,
                            partnerName: member.name,
                            messages: [],
                            lastMessageTime: nil,
                            lastMessagePreview: "",
                            unreadCount: 0
                        ))
                    },
                    isActive: Binding(
                        get: { selectedMember != nil },
                        set: { if !$0 { selectedMember = nil } }
                    )
                ) { EmptyView() }
            )
        }
    }
    
    private var filteredMembers: [CampMember] {
        if searchText.isEmpty {
            return meshtasticManager.campMembers
        }
        return meshtasticManager.campMembers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func selectMember(_ member: CampMember) {
        selectedMember = member
    }
}

// MARK: - Member Select Row

struct DMMemberSelectRow: View {
    let member: CampMember
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(member.name.prefix(1).uppercased())
                    .font(Theme.Typography.callout)
                    .foregroundColor(statusColor)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                
                HStack(spacing: Theme.Spacing.xs) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(member.status.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding()
    }
    
    private var statusColor: Color {
        switch member.status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.robotCream.opacity(0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    DirectMessagesView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocalDataManager.shared)
}
