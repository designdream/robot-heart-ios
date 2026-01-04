import Foundation
import Combine
import Network

/// Cloud synchronization service for opportunistic internet connectivity.
/// Automatically detects when device has internet and acts as a gateway node.
///
/// Features:
/// - Digital Ocean S3 integration for message storage
/// - Automatic gateway node promotion
/// - Store-and-forward with retry logic
/// - Message deduplication
/// - Network transition handling
@MainActor
class CloudSyncService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isOnline = false
    @Published var isGatewayNode = false
    @Published var pendingMessages: [QueuedMessage] = []
    @Published var syncStatus: SyncStatus = .offline
    
    enum SyncStatus {
        case offline
        case connecting
        case online
        case syncing
        case error(String)
        
        var description: String {
            switch self {
            case .offline: return "Offline"
            case .connecting: return "Connecting..."
            case .online: return "Online"
            case .syncing: return "Syncing..."
            case .error(let msg): return "Error: \(msg)"
            }
        }
    }
    
    // MARK: - Configuration
    
    private let campID: String
    private var s3Request: S3Request?
    
    // MARK: - Network Monitoring
    
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.robotheart.network-monitor")
    
    // MARK: - Retry Logic
    
    private var retryTimer: Timer?
    private let retryIntervals: [TimeInterval] = [5, 10, 30, 60, 300, 900, 3600] // 5s to 1h
    private var currentRetryIndex = 0
    
    // MARK: - Deduplication
    
    private var seenMessageIDs: Set<String> = []
    private let maxSeenMessages = 10000
    
    // MARK: - Initialization
    
    init(campID: String = "robot-heart") {
        self.campID = campID
        
        // Load S3 credentials from Keychain
        loadS3Credentials()
        
        startNetworkMonitoring()
        loadPendingMessages()
    }
    
    // MARK: - Credential Management
    
    private func loadS3Credentials() {
        do {
            let credentials = try KeychainService.shared.loadS3Credentials()
            
            s3Request = S3Request(
                endpoint: credentials.endpoint,
                bucket: credentials.bucket,
                region: credentials.region,
                accessKey: credentials.accessKey,
                secretKey: credentials.secretKey
            )
            
            print("☁️ [CloudSync] Loaded S3 credentials from Keychain")
        } catch {
            print("☁️ [CloudSync] No S3 credentials found: \(error.localizedDescription)")
            print("☁️ [CloudSync] Cloud sync disabled until credentials are configured")
        }
    }
    
    /// Check if S3 credentials are configured
    var hasCredentials: Bool {
        s3Request != nil
    }
    
    // MARK: - Network Monitoring
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handleNetworkChange(path: path)
            }
        }
        monitor.start(queue: monitorQueue)
    }
    
    private func handleNetworkChange(path: NWPath) {
        let wasOnline = isOnline
        isOnline = path.status == .satisfied
        
        if isOnline && !wasOnline {
            // Just came online
            print("☁️ [CloudSync] Network available, becoming gateway node")
            becomeGatewayNode()
        } else if !isOnline && wasOnline {
            // Just went offline
            print("☁️ [CloudSync] Network lost, resigning gateway node")
            resignGatewayNode()
        }
    }
    
    // MARK: - Gateway Node Management
    
    func becomeGatewayNode() {
        guard isOnline else { return }
        
        isGatewayNode = true
        syncStatus = .connecting
        
        // Start syncing pending messages
        Task {
            await syncPendingMessages()
        }
        
        // Start polling for cloud messages
        startCloudPolling()
        
        print("☁️ [CloudSync] Now acting as gateway node")
    }
    
    func resignGatewayNode() {
        isGatewayNode = false
        syncStatus = .offline
        stopCloudPolling()
        
        print("☁️ [CloudSync] Resigned as gateway node")
    }
    
    // MARK: - Message Queue
    
    struct QueuedMessage: Codable, Identifiable {
        let id: String
        let type: MessageType
        let from: String
        let fromName: String
        let content: String
        let location: Location?
        let timestamp: Date
        let ttl: TimeInterval
        var retryCount: Int = 0
        
        enum MessageType: String, Codable {
            case text, emergency, location, announcement
        }
        
        struct Location: Codable {
            let lat: Double
            let lon: Double
        }
    }
    
    func queueMessage(_ message: QueuedMessage) {
        // Check for duplicates
        guard !seenMessageIDs.contains(message.id) else {
            print("☁️ [CloudSync] Duplicate message \(message.id), skipping")
            return
        }
        
        pendingMessages.append(message)
        seenMessageIDs.insert(message.id)
        
        // Trim seen messages if too large
        if seenMessageIDs.count > maxSeenMessages {
            seenMessageIDs.removeAll()
        }
        
        savePendingMessages()
        
        // Try to send immediately if online
        if isGatewayNode {
            Task {
                await sendMessage(message)
            }
        }
    }
    
    // MARK: - Cloud Sync
    
    private func syncPendingMessages() async {
        guard isGatewayNode else { return }
        
        syncStatus = .syncing
        
        let messagesToSend = pendingMessages
        
        for message in messagesToSend {
            await sendMessage(message)
        }
        
        syncStatus = .online
    }
    
    private func sendMessage(_ message: QueuedMessage) async {
        guard isGatewayNode else { return }
        
        do {
            // Upload to S3
            let success = try await uploadToS3(message: message)
            
            if success {
                // Remove from queue
                pendingMessages.removeAll { $0.id == message.id }
                savePendingMessages()
                
                print("☁️ [CloudSync] Sent message \(message.id)")
            } else {
                // Retry later
                scheduleRetry(for: message)
            }
        } catch {
            print("☁️ [CloudSync] Failed to send message \(message.id): \(error)")
            scheduleRetry(for: message)
        }
    }
    
    private func uploadToS3(message: QueuedMessage) async throws -> Bool {
        guard let s3Request = s3Request else {
            print("☁️ [CloudSync] Cannot upload: S3 credentials not configured")
            return false
        }
        
        // Convert message to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(message)
        
        // S3 path: messages/{message_id}.json
        let s3Path = "messages/\(message.id).json"
        
        // Build signed PUT request
        let request = s3Request.buildPutRequest(
            path: s3Path,
            data: jsonData,
            contentType: "application/json"
        )
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return (200...299).contains(httpResponse.statusCode)
    }
    
    // MARK: - Cloud Polling
    
    private var pollTimer: Timer?
    
    private func startCloudPolling() {
        stopCloudPolling()
        
        // Poll every 30 seconds for new messages
        pollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchCloudMessages()
            }
        }
    }
    
    private func stopCloudPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func fetchCloudMessages() async {
        guard isGatewayNode, let s3Request = s3Request else { return }
        
        do {
            // Fetch message index for our camp
            let indexPath = "messages/index/\(campID).json"
            
            // Build signed GET request
            let request = s3Request.buildGetRequest(path: indexPath)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            // Parse message IDs
            let messageIDs = try JSONDecoder().decode([String].self, from: data)
            
            // Fetch any messages we haven't seen
            for messageID in messageIDs {
                if !seenMessageIDs.contains(messageID) {
                    await fetchAndRelayMessage(messageID: messageID)
                }
            }
        } catch {
            print("☁️ [CloudSync] Failed to fetch cloud messages: \(error)")
        }
    }
    
    private func fetchAndRelayMessage(messageID: String) async {
        guard let s3Request = s3Request else { return }
        
        do {
            let messagePath = "messages/\(messageID).json"
            
            // Build signed GET request
            let request = s3Request.buildGetRequest(path: messagePath)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let message = try JSONDecoder().decode(QueuedMessage.self, from: data)
            
            // Mark as seen
            seenMessageIDs.insert(messageID)
            
            // Relay to mesh network
            // This will be handled by NetworkOrchestrator
            NotificationCenter.default.post(
                name: .cloudMessageReceived,
                object: nil,
                userInfo: ["message": message]
            )
            
            print("☁️ [CloudSync] Relayed cloud message \(messageID) to mesh")
        } catch {
            print("☁️ [CloudSync] Failed to fetch message \(messageID): \(error)")
        }
    }
    
    // MARK: - Retry Logic
    
    private func scheduleRetry(for message: QueuedMessage) {
        // Update retry count
        if let index = pendingMessages.firstIndex(where: { $0.id == message.id }) {
            pendingMessages[index].retryCount += 1
            savePendingMessages()
        }
        
        // Schedule retry with exponential backoff
        let retryDelay = retryIntervals[min(currentRetryIndex, retryIntervals.count - 1)]
        currentRetryIndex += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) { [weak self] in
            Task {
                await self?.sendMessage(message)
            }
        }
        
        print("☁️ [CloudSync] Scheduled retry for \(message.id) in \(retryDelay)s")
    }
    
    // MARK: - Persistence
    
    private func loadPendingMessages() {
        guard let data = UserDefaults.standard.data(forKey: "pendingCloudMessages") else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            pendingMessages = try decoder.decode([QueuedMessage].self, from: data)
            
            print("☁️ [CloudSync] Loaded \(pendingMessages.count) pending messages")
        } catch {
            print("☁️ [CloudSync] Failed to load pending messages: \(error)")
        }
    }
    
    private func savePendingMessages() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(pendingMessages)
            UserDefaults.standard.set(data, forKey: "pendingCloudMessages")
        } catch {
            print("☁️ [CloudSync] Failed to save pending messages: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupExpiredMessages() {
        let now = Date()
        pendingMessages.removeAll { message in
            let age = now.timeIntervalSince(message.timestamp)
            return age > message.ttl
        }
        savePendingMessages()
        
        print("☁️ [CloudSync] Cleaned up expired messages, \(pendingMessages.count) remaining")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudMessageReceived = Notification.Name("cloudMessageReceived")
}
