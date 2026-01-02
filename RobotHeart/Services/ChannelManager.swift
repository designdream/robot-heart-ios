import Foundation
import Combine

// MARK: - Channel Manager
/// Manages topic-based channels for community communication
class ChannelManager: ObservableObject {
    // MARK: - Published Properties
    @Published var channels: [Channel] = []
    @Published var messages: [UUID: [ChannelMessage]] = [:] // channelID -> messages
    @Published var joinedChannelIDs: Set<UUID> = []
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let channelsKey = "channels"
    private let messagesKey = "channelMessages"
    private let joinedKey = "joinedChannels"
    private let currentUserID = "!local"
    
    // MARK: - Initialization
    init() {
        loadChannels()
        loadMessages()
        loadJoinedChannels()
        
        // Create default channels if none exist
        if channels.isEmpty {
            channels = Channel.defaultChannels
            // Auto-join default channels
            for channel in channels where channel.isDefault {
                joinedChannelIDs.insert(channel.id)
            }
            saveChannels()
            saveJoinedChannels()
        }
    }
    
    // MARK: - Channel Management
    
    /// Get channels the user has joined
    var myChannels: [Channel] {
        channels.filter { joinedChannelIDs.contains($0.id) }
    }
    
    /// Get available channels to join
    var availableChannels: [Channel] {
        channels.filter { !joinedChannelIDs.contains($0.id) && !$0.isPrivate }
    }
    
    /// Total unread count across all joined channels
    var totalUnreadCount: Int {
        myChannels.reduce(0) { $0 + $1.unreadCount }
    }
    
    /// Join a channel
    func joinChannel(_ channelID: UUID) {
        joinedChannelIDs.insert(channelID)
        saveJoinedChannels()
        
        // Add user to channel members
        if let index = channels.firstIndex(where: { $0.id == channelID }) {
            if !channels[index].memberIDs.contains(currentUserID) {
                channels[index].memberIDs.append(currentUserID)
                saveChannels()
            }
        }
    }
    
    /// Leave a channel
    func leaveChannel(_ channelID: UUID) {
        // Can't leave default channels
        guard let channel = channels.first(where: { $0.id == channelID }),
              !channel.isDefault else { return }
        
        joinedChannelIDs.remove(channelID)
        saveJoinedChannels()
        
        // Remove user from channel members
        if let index = channels.firstIndex(where: { $0.id == channelID }) {
            channels[index].memberIDs.removeAll { $0 == currentUserID }
            saveChannels()
        }
    }
    
    /// Create a new channel (admin only)
    func createChannel(name: String, description: String, icon: String = "number", isPrivate: Bool = false) -> Channel {
        let channel = Channel(
            name: name,
            description: description,
            icon: icon,
            isPrivate: isPrivate,
            createdBy: currentUserID
        )
        channels.append(channel)
        joinChannel(channel.id) // Auto-join created channel
        saveChannels()
        return channel
    }
    
    /// Delete a channel (admin only)
    func deleteChannel(_ channelID: UUID) {
        // Can't delete default channels
        guard let channel = channels.first(where: { $0.id == channelID }),
              !channel.isDefault else { return }
        
        channels.removeAll { $0.id == channelID }
        messages.removeValue(forKey: channelID)
        joinedChannelIDs.remove(channelID)
        saveChannels()
        saveMessages()
        saveJoinedChannels()
    }
    
    // MARK: - Messaging
    
    /// Get messages for a channel
    func messagesForChannel(_ channelID: UUID) -> [ChannelMessage] {
        messages[channelID] ?? []
    }
    
    /// Send a message to a channel
    func sendMessage(to channelID: UUID, content: String, senderName: String) {
        let message = ChannelMessage(
            channelID: channelID,
            senderID: currentUserID,
            senderName: senderName,
            content: content
        )
        
        if messages[channelID] == nil {
            messages[channelID] = []
        }
        messages[channelID]?.append(message)
        
        // Update channel's last message time
        if let index = channels.firstIndex(where: { $0.id == channelID }) {
            channels[index].lastMessageAt = Date()
        }
        
        saveMessages()
        saveChannels()
        
        // In production, this would broadcast via mesh network
        NotificationCenter.default.post(
            name: .channelMessageSent,
            object: message
        )
    }
    
    /// Mark all messages in a channel as read
    func markChannelAsRead(_ channelID: UUID) {
        if let index = channels.firstIndex(where: { $0.id == channelID }) {
            channels[index].unreadCount = 0
            saveChannels()
        }
        
        if var channelMessages = messages[channelID] {
            for i in channelMessages.indices {
                channelMessages[i].isRead = true
            }
            messages[channelID] = channelMessages
            saveMessages()
        }
    }
    
    /// Receive a message (from mesh network)
    func receiveMessage(_ message: ChannelMessage) {
        if messages[message.channelID] == nil {
            messages[message.channelID] = []
        }
        messages[message.channelID]?.append(message)
        
        // Increment unread count if not from current user
        if message.senderID != currentUserID {
            if let index = channels.firstIndex(where: { $0.id == message.channelID }) {
                channels[index].unreadCount += 1
                channels[index].lastMessageAt = message.timestamp
            }
        }
        
        saveMessages()
        saveChannels()
    }
    
    // MARK: - Direct Message Helpers (for unified people view)
    
    /// Get the last direct message with a specific person
    func lastDirectMessage(with memberID: String) -> ChannelMessage? {
        // For now, return nil - DMs are handled by MeshtasticManager
        // This is a placeholder for future DM integration
        return nil
    }
    
    /// Get unread direct message count with a specific person
    func unreadDirectMessageCount(with memberID: String) -> Int {
        // For now, return 0 - DMs are handled by MeshtasticManager
        // This is a placeholder for future DM integration
        return 0
    }
    
    // MARK: - Persistence
    
    private func saveChannels() {
        if let encoded = try? JSONEncoder().encode(channels) {
            userDefaults.set(encoded, forKey: channelsKey)
        }
    }
    
    private func loadChannels() {
        if let data = userDefaults.data(forKey: channelsKey),
           let decoded = try? JSONDecoder().decode([Channel].self, from: data) {
            channels = decoded
        }
    }
    
    private func saveMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            userDefaults.set(encoded, forKey: messagesKey)
        }
    }
    
    private func loadMessages() {
        if let data = userDefaults.data(forKey: messagesKey),
           let decoded = try? JSONDecoder().decode([UUID: [ChannelMessage]].self, from: data) {
            messages = decoded
        }
    }
    
    private func saveJoinedChannels() {
        let ids = Array(joinedChannelIDs).map { $0.uuidString }
        userDefaults.set(ids, forKey: joinedKey)
    }
    
    private func loadJoinedChannels() {
        if let ids = userDefaults.stringArray(forKey: joinedKey) {
            joinedChannelIDs = Set(ids.compactMap { UUID(uuidString: $0) })
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let channelMessageSent = Notification.Name("channelMessageSent")
}
