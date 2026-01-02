import Foundation
import Combine

// MARK: - Camp Network Manager
/// Manages multi-camp protocol for inter-camp communication at Burning Man.
///
/// This manager enables camps to discover each other, share events, request resources,
/// and coordinate across the playa - all without internet connectivity.
///
/// ## Multi-Camp Protocol
/// ```
/// ┌─────────────────┐         ┌─────────────────┐
/// │  Robot Heart    │◄──────►│  Dusty Disco    │
/// │  Camp (7:30&G)  │  Mesh   │  Camp (4:00&E)  │
/// └─────────────────┘         └─────────────────┘
///         │                           │
///         └───────────┬───────────────┘
///                     │
///                     ▼
///            ┌─────────────────┐
///            │  Sunrise Camp   │
///            │  (9:00&H)       │
///            └─────────────────┘
/// ```
///
/// ## Protocol Message Types
/// | Type | Purpose |
/// |------|---------|  
/// | `ping` | Discover nearby camps |
/// | `announce` | Broadcast camp info |
/// | `chat` | Camp-to-camp messaging |
/// | `resource` | Request water, ice, tools |
/// | `event` | Broadcast events to neighbors |
/// | `emergency` | Cross-camp emergency alerts |
///
/// ## Discovery Flow
/// 1. App broadcasts discovery ping every 5 minutes
/// 2. Nearby camps respond with announcements
/// 3. Discovered camps cached locally
/// 4. Stale camps (>24h) automatically cleaned up
///
/// ## Usage
/// ```swift
/// let network = CampNetworkManager.shared
/// network.setupCamp(name: "Robot Heart", location: "7:30 & G")
/// network.startDiscovery()
/// network.broadcastEvent(title: "Sunrise Set", ...)
/// ```
///
/// ## References
/// - See `docs/PROTOCOL.md` for message format specification
/// - See `docs/ARCHITECTURE.md` for full system design
class CampNetworkManager: ObservableObject {
    static let shared = CampNetworkManager()
    
    private let localData: LocalDataManager
    private let bleMesh: BLEMeshManager
    private let messageQueue: MessageQueueManager
    
    @Published var discoveredCamps: [DiscoveredCamp] = []
    @Published var myCamp: CampInfo?
    @Published var isDiscovering = false
    
    private var cancellables = Set<AnyCancellable>()
    private var broadcastTimer: Timer?
    
    // Protocol configuration
    private let protocolVersion: UInt8 = 1
    private let broadcastIntervalSeconds: TimeInterval = 300 // 5 minutes
    
    init(
        localData: LocalDataManager = .shared,
        bleMesh: BLEMeshManager = .shared,
        messageQueue: MessageQueueManager = .shared
    ) {
        self.localData = localData
        self.bleMesh = bleMesh
        self.messageQueue = messageQueue
        
        setupMessageHandling()
        loadMyCamp()
    }
    
    private func setupMessageHandling() {
        // Listen for camp announcements
        bleMesh.onMessageReceived = { [weak self] message in
            if message.messageType == .campAnnouncement {
                self?.handleCampAnnouncement(message)
            }
        }
    }
    
    private func loadMyCamp() {
        // Load camp info from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "myCampInfo"),
           let camp = try? JSONDecoder().decode(CampInfo.self, from: data) {
            myCamp = camp
        }
    }
    
    // MARK: - Camp Setup
    
    func setupCamp(
        name: String,
        location: String,
        description: String? = nil
    ) {
        let campID = UUID()
        
        myCamp = CampInfo(
            id: campID,
            name: name,
            location: location,
            description: description,
            memberCount: 1,
            createdAt: Date()
        )
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(myCamp) {
            UserDefaults.standard.set(data, forKey: "myCampInfo")
        }
        
        // Save to local database
        localData.saveCamp(
            id: campID,
            name: name,
            locationAddress: location,
            memberCount: 1
        )
        
        // Start broadcasting
        startBroadcasting()
    }
    
    func updateCampMemberCount(_ count: Int) {
        myCamp?.memberCount = count
        
        if let data = try? JSONEncoder().encode(myCamp) {
            UserDefaults.standard.set(data, forKey: "myCampInfo")
        }
    }
    
    // MARK: - Discovery
    
    func startDiscovery() {
        isDiscovering = true
        
        // Send discovery ping
        sendDiscoveryPing()
        
        // Also start BLE scanning
        bleMesh.startScanning()
    }
    
    func stopDiscovery() {
        isDiscovering = false
    }
    
    private func sendDiscoveryPing() {
        let ping = CampProtocolMessage(
            version: protocolVersion,
            type: .discoveryPing,
            campID: myCamp?.id.uuidString ?? "",
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            timestamp: Date(),
            payload: nil
        )
        
        if let data = try? JSONEncoder().encode(ping) {
            messageQueue.sendBroadcast(content: String(data: data, encoding: .utf8) ?? "", messageType: .campAnnouncement)
        }
    }
    
    // MARK: - Broadcasting
    
    func startBroadcasting() {
        guard myCamp != nil else { return }
        
        // Broadcast immediately
        broadcastCampAnnouncement()
        
        // Set up periodic broadcasts
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: broadcastIntervalSeconds, repeats: true) { [weak self] _ in
            self?.broadcastCampAnnouncement()
        }
    }
    
    func stopBroadcasting() {
        broadcastTimer?.invalidate()
        broadcastTimer = nil
    }
    
    private func broadcastCampAnnouncement() {
        guard let camp = myCamp else { return }
        
        let announcement = CampAnnouncement(
            campID: camp.id.uuidString,
            name: camp.name,
            location: camp.location,
            memberCount: camp.memberCount,
            description: camp.description
        )
        
        let message = CampProtocolMessage(
            version: protocolVersion,
            type: .campAnnouncement,
            campID: camp.id.uuidString,
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            timestamp: Date(),
            payload: try? JSONEncoder().encode(announcement)
        )
        
        if let data = try? JSONEncoder().encode(message) {
            messageQueue.sendBroadcast(content: String(data: data, encoding: .utf8) ?? "", messageType: .campAnnouncement)
        }
    }
    
    // MARK: - Message Handling
    
    private func handleCampAnnouncement(_ message: BLEMessage) {
        guard let data = message.content.data(using: .utf8),
              let protocolMessage = try? JSONDecoder().decode(CampProtocolMessage.self, from: data) else {
            return
        }
        
        switch protocolMessage.type {
        case .discoveryPing:
            // Respond with our camp info
            if myCamp != nil {
                broadcastCampAnnouncement()
            }
            
        case .campAnnouncement:
            if let payload = protocolMessage.payload,
               let announcement = try? JSONDecoder().decode(CampAnnouncement.self, from: payload) {
                handleCampDiscovery(announcement, from: protocolMessage)
            }
            
        case .resourceRequest:
            if let payload = protocolMessage.payload,
               let request = try? JSONDecoder().decode(ResourceRequest.self, from: payload) {
                handleResourceRequest(request, from: protocolMessage)
            }
            
        case .eventBroadcast:
            if let payload = protocolMessage.payload,
               let event = try? JSONDecoder().decode(EventBroadcast.self, from: payload) {
                handleEventBroadcast(event, from: protocolMessage)
            }
            
        default:
            break
        }
    }
    
    private func handleCampDiscovery(_ announcement: CampAnnouncement, from message: CampProtocolMessage) {
        // Don't add our own camp
        guard announcement.campID != myCamp?.id.uuidString else { return }
        
        let camp = DiscoveredCamp(
            id: announcement.campID,
            name: announcement.name,
            location: announcement.location,
            memberCount: announcement.memberCount,
            description: announcement.description,
            lastSeen: message.timestamp,
            signalStrength: 0 // TODO: Get from BLE RSSI
        )
        
        // Update or add camp
        if let index = discoveredCamps.firstIndex(where: { $0.id == camp.id }) {
            discoveredCamps[index] = camp
        } else {
            discoveredCamps.append(camp)
        }
        
        // Save to local database
        if let uuid = UUID(uuidString: announcement.campID) {
            localData.saveCamp(
                id: uuid,
                name: announcement.name,
                locationAddress: announcement.location,
                memberCount: Int32(announcement.memberCount)
            )
        }
    }
    
    private func handleResourceRequest(_ request: ResourceRequest, from message: CampProtocolMessage) {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .resourceRequestReceived,
            object: nil,
            userInfo: [
                "request": request,
                "fromCamp": message.campID
            ]
        )
    }
    
    private func handleEventBroadcast(_ event: EventBroadcast, from message: CampProtocolMessage) {
        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .eventBroadcastReceived,
            object: nil,
            userInfo: [
                "event": event,
                "fromCamp": message.campID
            ]
        )
    }
    
    // MARK: - Send to Camp
    
    func sendMessageToCamp(_ campID: String, content: String) {
        let message = CampProtocolMessage(
            version: protocolVersion,
            type: .chatMessage,
            campID: myCamp?.id.uuidString ?? "",
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            timestamp: Date(),
            payload: content.data(using: .utf8)
        )
        
        if let data = try? JSONEncoder().encode(message) {
            // Send to specific camp (use camp ID as recipient)
            messageQueue.sendMessage(
                to: campID,
                content: String(data: data, encoding: .utf8) ?? "",
                messageType: .campAnnouncement
            )
        }
    }
    
    func sendResourceRequest(type: String, description: String) {
        guard let camp = myCamp else { return }
        
        let request = ResourceRequest(
            id: UUID().uuidString,
            campID: camp.id.uuidString,
            campName: camp.name,
            resourceType: type,
            description: description,
            timestamp: Date()
        )
        
        let message = CampProtocolMessage(
            version: protocolVersion,
            type: .resourceRequest,
            campID: camp.id.uuidString,
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            timestamp: Date(),
            payload: try? JSONEncoder().encode(request)
        )
        
        if let data = try? JSONEncoder().encode(message) {
            messageQueue.sendBroadcast(content: String(data: data, encoding: .utf8) ?? "", messageType: .campAnnouncement)
        }
    }
    
    func broadcastEvent(title: String, description: String, time: Date, location: String) {
        guard let camp = myCamp else { return }
        
        let event = EventBroadcast(
            id: UUID().uuidString,
            campID: camp.id.uuidString,
            campName: camp.name,
            title: title,
            description: description,
            time: time,
            location: location
        )
        
        let message = CampProtocolMessage(
            version: protocolVersion,
            type: .eventBroadcast,
            campID: camp.id.uuidString,
            senderID: UserDefaults.standard.string(forKey: "userID") ?? "",
            timestamp: Date(),
            payload: try? JSONEncoder().encode(event)
        )
        
        if let data = try? JSONEncoder().encode(message) {
            messageQueue.sendBroadcast(content: String(data: data, encoding: .utf8) ?? "", messageType: .campAnnouncement)
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupOldCamps(olderThan hours: Int = 24) {
        let cutoff = Calendar.current.date(byAdding: .hour, value: -hours, to: Date())!
        discoveredCamps.removeAll { $0.lastSeen < cutoff }
    }
    
    deinit {
        broadcastTimer?.invalidate()
    }
}

// MARK: - Protocol Models

struct CampProtocolMessage: Codable {
    let version: UInt8
    let type: MessageType
    let campID: String
    let senderID: String
    let timestamp: Date
    let payload: Data?
    
    enum MessageType: String, Codable {
        case discoveryPing = "ping"
        case campAnnouncement = "announce"
        case chatMessage = "chat"
        case resourceRequest = "resource"
        case eventBroadcast = "event"
        case emergencyAlert = "emergency"
    }
}

struct CampInfo: Codable {
    let id: UUID
    var name: String
    var location: String
    var description: String?
    var memberCount: Int
    let createdAt: Date
}

struct DiscoveredCamp: Identifiable, Codable {
    let id: String
    let name: String
    let location: String
    let memberCount: Int
    let description: String?
    let lastSeen: Date
    var signalStrength: Int
}

struct CampAnnouncement: Codable {
    let campID: String
    let name: String
    let location: String
    let memberCount: Int
    let description: String?
}

struct ResourceRequest: Codable {
    let id: String
    let campID: String
    let campName: String
    let resourceType: String
    let description: String
    let timestamp: Date
}

struct EventBroadcast: Codable {
    let id: String
    let campID: String
    let campName: String
    let title: String
    let description: String
    let time: Date
    let location: String
}

// MARK: - Notification Names
extension Notification.Name {
    static let resourceRequestReceived = Notification.Name("resourceRequestReceived")
    static let eventBroadcastReceived = Notification.Name("eventBroadcastReceived")
    static let campDiscovered = Notification.Name("campDiscovered")
}
