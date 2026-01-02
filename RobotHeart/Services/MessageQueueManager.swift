import Foundation
import Combine

// MARK: - Message Queue Manager
/// Manages store-and-forward messaging for offline-first delivery
/// Handles message queuing, retry logic, and delivery confirmation
class MessageQueueManager: ObservableObject {
    static let shared = MessageQueueManager()
    
    private let localData: LocalDataManager
    private let bleMesh: BLEMeshManager
    private let meshtastic: MeshtasticManager
    
    @Published var pendingCount: Int = 0
    @Published var isProcessing = false
    
    private var retryTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Retry configuration
    private let maxRetries = 10
    private let retryIntervalSeconds: TimeInterval = 30
    private let exponentialBackoffMultiplier: Double = 1.5
    
    init(
        localData: LocalDataManager = .shared,
        bleMesh: BLEMeshManager = .shared,
        meshtastic: MeshtasticManager = MeshtasticManager()
    ) {
        self.localData = localData
        self.bleMesh = bleMesh
        self.meshtastic = meshtastic
        
        setupCallbacks()
        startRetryTimer()
    }
    
    private func setupCallbacks() {
        // Handle delivery confirmations from BLE
        bleMesh.onMessageReceived = { [weak self] message in
            if message.messageType == .deliveryConfirmation {
                self?.handleDeliveryConfirmation(messageID: message.content)
            } else {
                self?.handleIncomingMessage(message)
            }
        }
        
        // Observe pending count changes
        localData.$pendingMessageCount
            .receive(on: DispatchQueue.main)
            .assign(to: &$pendingCount)
    }
    
    // MARK: - Send Message
    
    func sendMessage(
        to recipientID: String,
        content: String,
        messageType: BLEMessage.MessageType = .text,
        locationLat: Double? = nil,
        locationLon: Double? = nil
    ) {
        let userID = UserDefaults.standard.string(forKey: "userID") ?? UUID().uuidString
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Unknown"
        
        let messageID = UUID()
        
        // Save to local database first (offline-first)
        localData.saveMessage(
            id: messageID,
            senderID: userID,
            senderName: userName,
            recipientID: recipientID,
            content: content,
            messageType: messageType.rawValue,
            locationLat: locationLat,
            locationLon: locationLon
        )
        
        // Create BLE message
        let bleMessage = BLEMessage(
            id: messageID.uuidString,
            senderID: userID,
            senderName: userName,
            recipientID: recipientID,
            messageType: messageType,
            content: content,
            timestamp: Date(),
            locationLat: locationLat,
            locationLon: locationLon
        )
        
        // Attempt immediate delivery via BLE mesh
        bleMesh.sendMessage(bleMessage)
        
        // Also try Meshtastic if available
        if meshtastic.isConnected {
            sendViaMeshtastic(bleMessage)
        }
    }
    
    func sendBroadcast(content: String, messageType: BLEMessage.MessageType = .text) {
        sendMessage(to: "broadcast", content: content, messageType: messageType)
    }
    
    func sendLocationShare(to recipientID: String, lat: Double, lon: Double) {
        let content = "\(lat),\(lon)"
        sendMessage(to: recipientID, content: content, messageType: .location, locationLat: lat, locationLon: lon)
    }
    
    func sendEmergency(content: String, lat: Double, lon: Double) {
        sendMessage(to: "broadcast", content: content, messageType: .emergency, locationLat: lat, locationLon: lon)
    }
    
    // MARK: - Meshtastic Integration
    
    private func sendViaMeshtastic(_ message: BLEMessage) {
        // Encode message for Meshtastic (max ~200 bytes)
        let compactMessage = CompactMessage(
            id: String(message.id.prefix(8)),
            from: String(message.senderID.prefix(8)),
            to: String(message.recipientID.prefix(8)),
            type: message.messageType.rawValue.first.map(String.init) ?? "t",
            content: String(message.content.prefix(150)),
            lat: message.locationLat,
            lon: message.locationLon
        )
        
        if let data = try? JSONEncoder().encode(compactMessage),
           let text = String(data: data, encoding: .utf8) {
            meshtastic.sendMessage(text) // Use existing sendMessage method
        }
    }
    
    // MARK: - Retry Logic
    
    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: retryIntervalSeconds, repeats: true) { [weak self] _ in
            self?.processPendingMessages()
        }
    }
    
    func processPendingMessages() {
        guard !isProcessing else { return }
        isProcessing = true
        
        let pending = localData.getPendingMessages()
        
        for message in pending {
            guard let messageID = message.id,
                  let recipientID = message.recipientID else { continue }
            
            // Check if we should retry
            let attempts = Int(message.attempts)
            if attempts >= maxRetries {
                continue // Already marked as failed
            }
            
            // Calculate backoff
            let backoff = retryIntervalSeconds * pow(exponentialBackoffMultiplier, Double(attempts))
            if let lastAttempt = message.lastAttempt,
               Date().timeIntervalSince(lastAttempt) < backoff {
                continue // Not time to retry yet
            }
            
            // Increment attempt counter
            localData.incrementPendingAttempt(messageID)
            
            // Try to send again
            let bleMessage = BLEMessage(
                id: messageID.uuidString,
                senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
                senderName: UserDefaults.standard.string(forKey: "userName") ?? "",
                recipientID: recipientID,
                messageType: BLEMessage.MessageType(rawValue: message.messageType ?? "text") ?? .text,
                content: "", // Content is encrypted in payload
                timestamp: message.createdAt ?? Date()
            )
            
            bleMesh.sendMessage(bleMessage)
            
            if meshtastic.isConnected {
                sendViaMeshtastic(bleMessage)
            }
        }
        
        isProcessing = false
    }
    
    // MARK: - Delivery Confirmation
    
    private func handleDeliveryConfirmation(messageID: String) {
        guard let uuid = UUID(uuidString: messageID) else { return }
        
        // Mark message as delivered in local database
        localData.markMessageDelivered(uuid)
        
        print("Message \(messageID) delivered successfully")
    }
    
    // MARK: - Incoming Messages
    
    private func handleIncomingMessage(_ message: BLEMessage) {
        guard let uuid = UUID(uuidString: message.id) else { return }
        
        // Save to local database
        localData.saveMessage(
            id: uuid,
            senderID: message.senderID,
            senderName: message.senderName,
            recipientID: message.recipientID,
            content: message.content,
            messageType: message.messageType.rawValue,
            locationLat: message.locationLat,
            locationLon: message.locationLon
        )
        
        // Post notification for UI
        NotificationCenter.default.post(
            name: .newMessageReceived,
            object: nil,
            userInfo: ["message": message]
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        localData.cleanupExpiredMessages()
        localData.cleanupOldSyncItems()
    }
    
    deinit {
        retryTimer?.invalidate()
    }
}

// MARK: - Compact Message (for Meshtastic)
struct CompactMessage: Codable {
    let id: String      // 8 chars
    let from: String    // 8 chars
    let to: String      // 8 chars
    let type: String    // 1 char
    let content: String // up to 150 chars
    let lat: Double?
    let lon: Double?
}

// MARK: - Notification Names
extension Notification.Name {
    static let newMessageReceived = Notification.Name("newMessageReceived")
    static let messageDelivered = Notification.Name("messageDelivered")
}
