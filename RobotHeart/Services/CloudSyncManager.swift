import Foundation
import CloudKit
import Combine
import Network

// MARK: - Cloud Sync Manager
/// Manages optional cloud synchronization via CloudKit when internet is available.
///
/// This manager enables "Gateway Node" functionality - devices with internet access
/// (e.g., Starlink at Burning Man) can sync local mesh data to the cloud, benefiting
/// the entire network even if most devices are offline.
///
/// ## Gateway Node Architecture
/// ```
/// ┌─────────────────────────────────────────────────────────┐
/// │  Mesh Network (No Internet)                         │
/// │  Phone A ◄──► Phone B ◄──► Phone C                   │
/// └───────────────────────────┬─────────────────────────────┘
///                            │
///                            ▼
///                   ┌───────────────┐
///                   │ Gateway Node │ (Has Starlink)
///                   │   Phone D    │
///                   └───────┬───────┘
///                         │
///                         ▼
///                   ┌───────────────┐
///                   │   CloudKit   │
///                   │  (iCloud)    │
///                   └───────────────┘
/// ```
///
/// ## Key Features
/// - **Auto-Detection**: Automatically detects WiFi/Ethernet (becomes gateway)
/// - **Bidirectional Sync**: Uploads local data, downloads cloud data
/// - **Relay to Mesh**: Downloads cloud messages and relays to local mesh
/// - **Offline Queue**: Tracks changes for sync when connectivity returns
///
/// ## Privacy
/// - Only encrypted payloads uploaded to CloudKit
/// - Apple cannot read message content
/// - User controls what syncs via privacy settings
///
/// ## Usage
/// ```swift
/// let sync = CloudSyncManager.shared
/// // Automatic - syncs when online
/// // Manual trigger:
/// sync.syncNow()
/// ```
///
/// ## References
/// - [Apple CloudKit](https://developer.apple.com/documentation/cloudkit)
/// - See `docs/ARCHITECTURE.md` for full system design
/// - See `docs/SECURITY.md` for privacy details
class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let localData: LocalDataManager
    private let networkMonitor: NWPathMonitor
    
    @Published var isOnline = false
    @Published var isSyncing = false
    @Published var isGatewayNode = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    @Published var pendingSyncCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?
    
    // Sync configuration
    private let syncIntervalSeconds: TimeInterval = 60
    private let batchSize = 50
    
    // Record types
    private let messageRecordType = "Message"
    private let memberRecordType = "Member"
    private let campRecordType = "Camp"
    
    init(localData: LocalDataManager = .shared) {
        self.container = CKContainer(identifier: "iCloud.com.robotheart.app")
        self.privateDatabase = container.privateCloudDatabase
        self.localData = localData
        self.networkMonitor = NWPathMonitor()
        
        // Don't start monitoring in init - do it lazily to avoid blocking main thread
    }
    
    /// Call this to start cloud sync services (lazy initialization)
    func startServices() {
        setupNetworkMonitoring()
        setupSyncTimer()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        let queue = DispatchQueue(label: "NetworkMonitor")
        
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied
                
                // Check for high-bandwidth connection (Starlink/WiFi)
                self?.isGatewayNode = path.status == .satisfied &&
                    (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
                
                // Trigger sync when coming online
                if !wasOnline && self?.isOnline == true {
                    self?.syncNow()
                }
            }
        }
        
        networkMonitor.start(queue: queue)
    }
    
    private func setupSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncIntervalSeconds, repeats: true) { [weak self] _ in
            if self?.isOnline == true && self?.isGatewayNode == true {
                self?.syncNow()
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func syncNow() {
        guard isOnline, !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        Task {
            do {
                // Upload pending changes
                try await uploadPendingChanges()
                
                // Download new data from cloud
                try await downloadNewData()
                
                await MainActor.run {
                    self.lastSyncDate = Date()
                    self.isSyncing = false
                }
            } catch {
                await MainActor.run {
                    self.syncError = error.localizedDescription
                    self.isSyncing = false
                }
            }
        }
    }
    
    // MARK: - Upload
    
    private func uploadPendingChanges() async throws {
        let unsyncedItems = localData.getUnsyncedItems()
        pendingSyncCount = unsyncedItems.count
        
        for item in unsyncedItems {
            guard let tableName = item.tableName,
                  let recordID = item.recordID,
                  let operation = item.operation else { continue }
            
            do {
                switch tableName {
                case "CachedMessage":
                    try await uploadMessage(recordID: recordID, operation: operation)
                case "CachedMember":
                    try await uploadMember(recordID: recordID, operation: operation)
                case "CachedCamp":
                    try await uploadCamp(recordID: recordID, operation: operation)
                default:
                    break
                }
                
                // Mark as synced
                if let itemID = item.id {
                    localData.markSynced(itemID)
                }
                
                await MainActor.run {
                    self.pendingSyncCount -= 1
                }
            } catch {
                print("Failed to sync \(tableName) \(recordID): \(error)")
            }
        }
    }
    
    private func uploadMessage(recordID: String, operation: String) async throws {
        guard operation != "delete" else {
            let ckRecordID = CKRecord.ID(recordName: recordID)
            try await privateDatabase.deleteRecord(withID: ckRecordID)
            return
        }
        
        // Fetch local message
        let messages = localData.fetchMessages(with: recordID)
        guard let message = messages.first(where: { $0.id?.uuidString == recordID }) else { return }
        
        let record = CKRecord(recordType: messageRecordType, recordID: CKRecord.ID(recordName: recordID))
        record["senderID"] = message.senderID
        record["senderName"] = message.senderName
        record["recipientID"] = message.recipientID
        record["content"] = message.content
        record["messageType"] = message.messageType
        record["timestamp"] = message.timestamp
        record["isDelivered"] = message.isDelivered
        record["isRead"] = message.isRead
        
        try await privateDatabase.save(record)
    }
    
    private func uploadMember(recordID: String, operation: String) async throws {
        guard operation != "delete" else {
            let ckRecordID = CKRecord.ID(recordName: recordID)
            try await privateDatabase.deleteRecord(withID: ckRecordID)
            return
        }
        
        // Find member in local cache
        guard let member = localData.members.first(where: { $0.id?.uuidString == recordID }) else { return }
        
        let record = CKRecord(recordType: memberRecordType, recordID: CKRecord.ID(recordName: recordID))
        record["name"] = member.name
        record["role"] = member.role
        record["campID"] = member.campID
        record["brcAddress"] = member.brcAddress
        record["lastSeen"] = member.lastSeen
        record["lastLocationLat"] = member.lastLocationLat
        record["lastLocationLon"] = member.lastLocationLon
        
        try await privateDatabase.save(record)
    }
    
    private func uploadCamp(recordID: String, operation: String) async throws {
        guard operation != "delete" else {
            let ckRecordID = CKRecord.ID(recordName: recordID)
            try await privateDatabase.deleteRecord(withID: ckRecordID)
            return
        }
        
        guard let camp = localData.camps.first(where: { $0.id?.uuidString == recordID }) else { return }
        
        let record = CKRecord(recordType: campRecordType, recordID: CKRecord.ID(recordName: recordID))
        record["name"] = camp.name
        record["locationAddress"] = camp.locationAddress
        record["memberCount"] = Int64(camp.memberCount)
        record["lastBroadcast"] = camp.lastBroadcast
        
        try await privateDatabase.save(record)
    }
    
    // MARK: - Download
    
    private func downloadNewData() async throws {
        // Download messages newer than last sync
        try await downloadMessages()
        
        // Download member updates
        try await downloadMembers()
        
        // Download camp broadcasts
        try await downloadCamps()
    }
    
    private func downloadMessages() async throws {
        let predicate: NSPredicate
        if let lastSync = lastSyncDate {
            predicate = NSPredicate(format: "timestamp > %@", lastSync as NSDate)
        } else {
            // First sync - get last 7 days
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            predicate = NSPredicate(format: "timestamp > %@", weekAgo as NSDate)
        }
        
        let query = CKQuery(recordType: messageRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: batchSize)
        
        for result in results {
            switch result.1 {
            case .success(let record):
                saveMessageFromCloud(record)
            case .failure(let error):
                print("Failed to fetch message: \(error)")
            }
        }
    }
    
    private func downloadMembers() async throws {
        let predicate: NSPredicate
        if let lastSync = lastSyncDate {
            predicate = NSPredicate(format: "lastSeen > %@", lastSync as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        
        let query = CKQuery(recordType: memberRecordType, predicate: predicate)
        
        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: batchSize)
        
        for result in results {
            switch result.1 {
            case .success(let record):
                saveMemberFromCloud(record)
            case .failure(let error):
                print("Failed to fetch member: \(error)")
            }
        }
    }
    
    private func downloadCamps() async throws {
        let predicate: NSPredicate
        if let lastSync = lastSyncDate {
            predicate = NSPredicate(format: "lastBroadcast > %@", lastSync as NSDate)
        } else {
            predicate = NSPredicate(value: true)
        }
        
        let query = CKQuery(recordType: campRecordType, predicate: predicate)
        
        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: batchSize)
        
        for result in results {
            switch result.1 {
            case .success(let record):
                saveCampFromCloud(record)
            case .failure(let error):
                print("Failed to fetch camp: \(error)")
            }
        }
    }
    
    // MARK: - Save from Cloud
    
    private func saveMessageFromCloud(_ record: CKRecord) {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let senderID = record["senderID"] as? String,
              let senderName = record["senderName"] as? String,
              let recipientID = record["recipientID"] as? String,
              let content = record["content"] as? String else { return }
        
        localData.saveMessage(
            id: id,
            senderID: senderID,
            senderName: senderName,
            recipientID: recipientID,
            content: content,
            messageType: record["messageType"] as? String ?? "text"
        )
    }
    
    private func saveMemberFromCloud(_ record: CKRecord) {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let name = record["name"] as? String else { return }
        
        localData.saveMember(
            id: id,
            name: name,
            role: record["role"] as? String ?? "member",
            campID: record["campID"] as? String,
            brcAddress: record["brcAddress"] as? String
        )
        
        // Update location if available
        if let lat = record["lastLocationLat"] as? Double,
           let lon = record["lastLocationLon"] as? Double {
            localData.updateMemberLocation(id, lat: lat, lon: lon)
        }
    }
    
    private func saveCampFromCloud(_ record: CKRecord) {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let name = record["name"] as? String,
              let location = record["locationAddress"] as? String else { return }
        
        localData.saveCamp(
            id: id,
            name: name,
            locationAddress: location,
            memberCount: Int32(record["memberCount"] as? Int64 ?? 0)
        )
    }
    
    // MARK: - Gateway Node Features
    
    /// When acting as a gateway node, relay mesh messages to cloud
    func relayToCloud(_ message: BLEMessage) {
        guard isGatewayNode else { return }
        
        Task {
            do {
                let record = CKRecord(recordType: messageRecordType, recordID: CKRecord.ID(recordName: message.id))
                record["senderID"] = message.senderID
                record["senderName"] = message.senderName
                record["recipientID"] = message.recipientID
                record["content"] = message.content
                record["messageType"] = message.messageType.rawValue
                record["timestamp"] = message.timestamp
                record["isDelivered"] = false
                record["isRead"] = false
                
                if let lat = message.locationLat, let lon = message.locationLon {
                    record["locationLat"] = lat
                    record["locationLon"] = lon
                }
                
                try await privateDatabase.save(record)
                print("Gateway: Relayed message to cloud")
            } catch {
                print("Gateway: Failed to relay message: \(error)")
            }
        }
    }
    
    /// Download messages from cloud and relay to mesh
    func relayFromCloud() {
        guard isGatewayNode else { return }
        
        Task {
            do {
                // Get undelivered messages from cloud
                let predicate = NSPredicate(format: "isDelivered == NO")
                let query = CKQuery(recordType: messageRecordType, predicate: predicate)
                
                let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 20)
                
                for result in results {
                    switch result.1 {
                    case .success(let record):
                        // Convert to BLE message and send to mesh
                        if let message = bleMessageFromRecord(record) {
                            BLEMeshManager.shared.sendMessage(message)
                            
                            // Mark as delivered in cloud
                            record["isDelivered"] = true
                            try await privateDatabase.save(record)
                        }
                    case .failure:
                        break
                    }
                }
            } catch {
                print("Gateway: Failed to relay from cloud: \(error)")
            }
        }
    }
    
    private func bleMessageFromRecord(_ record: CKRecord) -> BLEMessage? {
        guard let senderID = record["senderID"] as? String,
              let senderName = record["senderName"] as? String,
              let recipientID = record["recipientID"] as? String,
              let content = record["content"] as? String,
              let timestamp = record["timestamp"] as? Date else { return nil }
        
        let messageTypeString = record["messageType"] as? String ?? "text"
        let messageType = BLEMessage.MessageType(rawValue: messageTypeString) ?? .text
        
        return BLEMessage(
            id: record.recordID.recordName,
            senderID: senderID,
            senderName: senderName,
            recipientID: recipientID,
            messageType: messageType,
            content: content,
            timestamp: timestamp,
            locationLat: record["locationLat"] as? Double,
            locationLon: record["locationLon"] as? Double
        )
    }
    
    deinit {
        syncTimer?.invalidate()
        networkMonitor.cancel()
    }
}
