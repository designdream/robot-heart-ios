import Foundation
import Combine

/// Service responsible for handling Meshtastic message sending and receiving.
/// Manages message history, delivery status, and offline queue.
@MainActor
class MeshtasticMessageService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var messages: [Message] = []
    @Published var unreadCount: Int = 0
    
    // MARK: - Private Properties
    
    private let protocolService = MeshtasticProtocolService.shared
    private let userDefaults = UserDefaults.standard
    private let messagesKey = "meshtastic_messages"
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var sendData: ((Data) throws -> Void)?
    var onMessageReceived: ((Message) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadPersistedMessages()
    }
    
    // MARK: - Public Methods
    
    /// Send a text message
    func sendMessage(_ text: String, to nodeID: UInt32? = nil, wantAck: Bool = false) throws {
        // Encode message
        let packet = try protocolService.encodeTextMessage(text, to: nodeID, wantAck: wantAck)
        
        // Send via connection service
        try sendData?(packet)
        
        // Create message record
        let message = Message(
            id: UUID().uuidString,
            text: text,
            senderID: "me",
            senderName: "Me",
            timestamp: Date(),
            isFromMe: true,
            channel: nodeID.map { "\($0)" } ?? "broadcast",
            deliveryStatus: .sent
        )
        
        // Add to history
        addMessage(message)
        
        print("📤 [MeshtasticMessage] Sent message: \(text.prefix(50))...")
    }
    
    /// Process received packet data
    func processReceivedPacket(_ data: Data) {
        do {
            // Decode packet
            let packet = try protocolService.decodePacket(data)
            
            // Handle based on port number
            switch packet.portNum {
            case .textMessage:
                handleTextMessage(packet)
                
            case .textMessageCompressed:
                // TODO: Implement decompression
                print("📥 [MeshtasticMessage] Received compressed text (not yet implemented)")
                
            default:
                // Not a message packet, ignore
                break
            }
            
        } catch {
            print("❌ [MeshtasticMessage] Failed to process packet: \(error.localizedDescription)")
        }
    }
    
    /// Get messages for a specific channel/node
    func getMessages(for channelID: String?) -> [Message] {
        if let channelID = channelID {
            return messages.filter { $0.channel == channelID }
        } else {
            return messages.filter { $0.channel == "broadcast" }
        }
    }
    
    /// Mark a message as read
    func markAsRead(_ messageID: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        
        messages[index].isRead = true
        updateUnreadCount()
        persistMessages()
    }
    
    /// Mark all messages as read
    func markAllAsRead() {
        for index in messages.indices {
            messages[index].isRead = true
        }
        updateUnreadCount()
        persistMessages()
    }
    
    /// Delete a message
    func deleteMessage(_ messageID: String) {
        messages.removeAll { $0.id == messageID }
        updateUnreadCount()
        persistMessages()
        
        print("📥 [MeshtasticMessage] Deleted message: \(messageID)")
    }
    
    /// Clear all messages
    func clearAllMessages() {
        messages.removeAll()
        unreadCount = 0
        persistMessages()
        
        print("📥 [MeshtasticMessage] Cleared all messages")
    }
    
    /// Get message statistics
    func getMessageStats() -> MessageStats {
        let total = messages.count
        let sent = messages.filter { $0.isFromMe }.count
        let received = messages.filter { !$0.isFromMe }.count
        let unread = messages.filter { !$0.isRead && !$0.isFromMe }.count
        
        return MessageStats(
            total: total,
            sent: sent,
            received: received,
            unread: unread
        )
    }
    
    // MARK: - Private Methods
    
    private func handleTextMessage(_ packet: MeshtasticPacket) {
        do {
            // Decode text
            let text = try protocolService.decodeTextMessage(from: packet.payload)
            
            // Create message
            let message = Message(
                id: UUID().uuidString,
                text: text,
                senderID: "\(packet.fromNodeID)",
                senderName: "Node \(packet.fromNodeID)", // TODO: Look up actual name from NodeService
                timestamp: Date(),
                isFromMe: false,
                channel: "broadcast",
                deliveryStatus: .delivered
            )
            
            // Add to history
            addMessage(message)
            
            // Notify callback
            onMessageReceived?(message)
            
            print("📥 [MeshtasticMessage] Received message from \(packet.fromNodeID): \(text.prefix(50))...")
            
        } catch {
            print("❌ [MeshtasticMessage] Failed to decode text message: \(error.localizedDescription)")
        }
    }
    
    private func addMessage(_ message: Message) {
        messages.append(message)
        
        // Keep only last 1000 messages
        if messages.count > 1000 {
            messages = Array(messages.suffix(1000))
        }
        
        updateUnreadCount()
        persistMessages()
    }
    
    private func updateUnreadCount() {
        unreadCount = messages.filter { !$0.isRead && !$0.isFromMe }.count
    }
    
    private func persistMessages() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(messages) {
            userDefaults.set(encoded, forKey: messagesKey)
        }
    }
    
    private func loadPersistedMessages() {
        guard let data = userDefaults.data(forKey: messagesKey) else { return }
        
        let decoder = JSONDecoder()
        if let loadedMessages = try? decoder.decode([Message].self, from: data) {
            messages = loadedMessages
            updateUnreadCount()
            print("📥 [MeshtasticMessage] Loaded \(messages.count) persisted messages")
        }
    }
}

// MARK: - Supporting Types

struct MessageStats {
    let total: Int
    let sent: Int
    let received: Int
    let unread: Int
}

// MARK: - Message Extension

extension Message {
    /// Check if this is an emergency message
    var isEmergency: Bool {
        text.contains("[SOS]") || text.contains("[EMERGENCY]")
    }
    
    /// Check if this is a system message
    var isSystem: Bool {
        text.hasPrefix("[") && text.contains("]")
    }
    
    /// Extract message type from prefix
    var messageType: MessageType {
        if text.hasPrefix("[SOS]") { return .sos }
        if text.hasPrefix("[ICE]") { return .ice }
        if text.hasPrefix("[WATER]") { return .water }
        if text.hasPrefix("[SHIFT]") { return .shift }
        if text.hasPrefix("[WHITEOUT]") { return .whiteout }
        return .text
    }
    
    enum MessageType {
        case text
        case sos
        case ice
        case water
        case shift
        case whiteout
        
        var icon: String {
            switch self {
            case .text: return "💬"
            case .sos: return "🆘"
            case .ice: return "🧊"
            case .water: return "💧"
            case .shift: return "🔄"
            case .whiteout: return "🌫️"
            }
        }
        
        var color: String {
            switch self {
            case .text: return "primary"
            case .sos: return "red"
            case .ice: return "blue"
            case .water: return "cyan"
            case .shift: return "orange"
            case .whiteout: return "gray"
            }
        }
    }
}
