import Foundation

// MARK: - Channel Model
/// Topic-based group chat channels within the camp community
/// Like WhatsApp groups within a community
struct Channel: Identifiable, Codable {
    let id: UUID
    var name: String // e.g., "general", "bus", "kitchen"
    var displayName: String // e.g., "#general", "#bus"
    var description: String
    var icon: String // SF Symbol name
    var color: String // Hex color for the channel
    var isDefault: Bool // Default channels everyone joins
    var isPrivate: Bool // Invite-only channels
    var createdBy: String // Member ID who created it
    var createdAt: Date
    var memberIDs: [String] // Members who joined this channel
    var lastMessageAt: Date?
    var unreadCount: Int
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        icon: String = "number",
        color: String = "turquoise",
        isDefault: Bool = false,
        isPrivate: Bool = false,
        createdBy: String = "!local"
    ) {
        self.id = id
        self.name = name.lowercased().replacingOccurrences(of: " ", with: "-")
        self.displayName = "#\(self.name)"
        self.description = description
        self.icon = icon
        self.color = color
        self.isDefault = isDefault
        self.isPrivate = isPrivate
        self.createdBy = createdBy
        self.createdAt = Date()
        self.memberIDs = []
        self.lastMessageAt = nil
        self.unreadCount = 0
    }
}

// MARK: - Channel Message
struct ChannelMessage: Identifiable, Codable {
    let id: UUID
    let channelID: UUID
    let senderID: String
    let senderName: String
    let content: String
    let timestamp: Date
    var isRead: Bool
    
    init(
        id: UUID = UUID(),
        channelID: UUID,
        senderID: String,
        senderName: String,
        content: String
    ) {
        self.id = id
        self.channelID = channelID
        self.senderID = senderID
        self.senderName = senderName
        self.content = content
        self.timestamp = Date()
        self.isRead = false
    }
}

// MARK: - Default Channels
extension Channel {
    static let defaultChannels: [Channel] = [
        Channel(
            name: "general",
            description: "Camp-wide chat for everyone",
            icon: "megaphone.fill",
            color: "sunsetOrange",
            isDefault: true
        ),
        Channel(
            name: "bus",
            description: "Bus crew coordination",
            icon: "bus.fill",
            color: "sunsetOrange",
            isDefault: false
        ),
        Channel(
            name: "kitchen",
            description: "Kitchen & food coordination",
            icon: "fork.knife",
            color: "goldenYellow",
            isDefault: false
        ),
        Channel(
            name: "build",
            description: "Build crew & infrastructure",
            icon: "hammer.fill",
            color: "turquoise",
            isDefault: false
        ),
        Channel(
            name: "shady",
            description: "Shady Bot crew",
            icon: "sparkles",
            color: "dustyPink",
            isDefault: false
        ),
        Channel(
            name: "help",
            description: "Need help with something?",
            icon: "hand.raised.fill",
            color: "emergency",
            isDefault: true
        ),
        Channel(
            name: "lost-found",
            description: "Lost items & found treasures",
            icon: "magnifyingglass",
            color: "robotCream",
            isDefault: true
        ),
        Channel(
            name: "rides",
            description: "Ride sharing to/from playa",
            icon: "car.fill",
            color: "connected",
            isDefault: false
        )
    ]
}
