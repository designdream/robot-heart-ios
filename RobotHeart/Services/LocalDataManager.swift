import Foundation
import CoreData
import Combine

// MARK: - Local Data Manager
/// Central data access layer for the offline-first architecture.
///
/// This manager provides a unified interface for all local data operations,
/// ensuring data is always available even without network connectivity.
/// It's the foundation of the "offline-first" design philosophy.
///
/// ## Core Responsibilities
/// - **Message Storage**: All messages cached locally before/after transmission
/// - **Member Directory**: Cached member info from mesh network
/// - **Camp Registry**: Discovered camps from multi-camp protocol
/// - **Pending Queue**: Messages awaiting delivery (store-and-forward)
/// - **Sync Queue**: Changes awaiting cloud sync (when gateway available)
///
/// ## Data Flow
/// ```
/// User Action → LocalDataManager → Core Data (SQLite)
///                    │
///                    ├──► PendingQueue → MessageQueueManager → Mesh
///                    └──► SyncQueue → CloudSyncManager → CloudKit
/// ```
///
/// ## Thread Safety
/// - Uses Core Data's `viewContext` for main thread operations
/// - Background operations use `performBackgroundTask`
/// - Automatic merge from parent context
///
/// ## Usage
/// ```swift
/// let data = LocalDataManager.shared
/// 
/// // Save a message (automatically queued for delivery)
/// data.saveMessage(senderID: "me", recipientID: "them", content: "Hello!")
/// 
/// // Fetch messages for a conversation
/// let messages = data.fetchMessages(with: "user-123")
/// 
/// // Mark message as delivered
/// data.markMessageDelivered(messageID)
/// ```
///
/// ## References
/// - [Apple Core Data](https://developer.apple.com/documentation/coredata)
/// - See `docs/ARCHITECTURE.md` for full system design
class LocalDataManager: ObservableObject {
    static let shared = LocalDataManager()
    
    private let persistence: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // Published properties for UI binding
    @Published var messages: [CachedMessage] = []
    @Published var members: [CachedMember] = []
    @Published var camps: [CachedCamp] = []
    @Published var pendingMessageCount: Int = 0
    
    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        // Don't setup observers or load data in init - do it lazily
    }
    
    /// Call this to start data services (lazy initialization)
    func startServices() {
        setupObservers()
        loadInitialData()
    }
    
    private func setupObservers() {
        // Observe Core Data changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        refreshData()
    }
    
    private func refreshData() {
        fetchMessages()
        fetchMembers()
        fetchCamps()
        updatePendingCount()
    }
    
    // MARK: - Message Operations
    
    func fetchMessages(limit: Int = 100) {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMessage.timestamp, ascending: false)]
        request.fetchLimit = limit
        
        do {
            messages = try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch messages: \(error)")
        }
    }
    
    func fetchMessages(with recipientID: String) -> [CachedMessage] {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "recipientID == %@ OR senderID == %@", recipientID, recipientID)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMessage.timestamp, ascending: true)]
        
        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch messages for recipient: \(error)")
            return []
        }
    }
    
    @discardableResult
    func saveMessage(
        id: UUID = UUID(),
        senderID: String,
        senderName: String,
        recipientID: String,
        content: String,
        messageType: String = "text",
        locationLat: Double? = nil,
        locationLon: Double? = nil,
        encryptedPayload: Data? = nil
    ) -> CachedMessage {
        let context = persistence.viewContext
        let message = CachedMessage(context: context)
        
        message.id = id
        message.senderID = senderID
        message.senderName = senderName
        message.recipientID = recipientID
        message.content = content
        message.messageType = messageType
        message.timestamp = Date()
        message.isDelivered = false
        message.isRead = false
        message.encryptedPayload = encryptedPayload
        
        if let lat = locationLat, let lon = locationLon {
            message.locationLat = lat
            message.locationLon = lon
        }
        
        persistence.save()
        
        // Add to sync queue
        addToSyncQueue(tableName: "CachedMessage", recordID: id.uuidString, operation: "insert")
        
        // Add to pending queue for delivery
        addToPendingQueue(messageID: id, recipientID: recipientID, messageType: messageType, payload: encryptedPayload)
        
        return message
    }
    
    func markMessageDelivered(_ messageID: UUID) {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", messageID as CVarArg)
        
        do {
            if let message = try persistence.viewContext.fetch(request).first {
                message.isDelivered = true
                persistence.save()
                
                // Remove from pending queue
                removePendingMessage(messageID)
                
                // Update sync queue
                addToSyncQueue(tableName: "CachedMessage", recordID: messageID.uuidString, operation: "update")
            }
        } catch {
            print("Failed to mark message delivered: \(error)")
        }
    }
    
    func markMessageRead(_ messageID: UUID) {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", messageID as CVarArg)
        
        do {
            if let message = try persistence.viewContext.fetch(request).first {
                message.isRead = true
                persistence.save()
                addToSyncQueue(tableName: "CachedMessage", recordID: messageID.uuidString, operation: "update")
            }
        } catch {
            print("Failed to mark message read: \(error)")
        }
    }
    
    // MARK: - Member Operations
    
    func fetchMembers() {
        let request: NSFetchRequest<CachedMember> = CachedMember.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMember.name, ascending: true)]
        
        do {
            members = try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch members: \(error)")
        }
    }
    
    @discardableResult
    func saveMember(
        id: UUID = UUID(),
        name: String,
        role: String = "member",
        campID: String? = nil,
        brcAddress: String? = nil,
        publicKey: Data? = nil
    ) -> CachedMember {
        let context = persistence.viewContext
        
        // Check if member already exists
        let request: NSFetchRequest<CachedMember> = CachedMember.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let member: CachedMember
        if let existing = try? context.fetch(request).first {
            member = existing
        } else {
            member = CachedMember(context: context)
            member.id = id
        }
        
        member.name = name
        member.role = role
        member.campID = campID
        member.brcAddress = brcAddress
        member.publicKey = publicKey
        member.lastSeen = Date()
        
        persistence.save()
        addToSyncQueue(tableName: "CachedMember", recordID: id.uuidString, operation: "upsert")
        
        return member
    }
    
    func updateMemberLocation(_ memberID: UUID, lat: Double, lon: Double, brcAddress: String? = nil) {
        let request: NSFetchRequest<CachedMember> = CachedMember.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", memberID as CVarArg)
        
        do {
            if let member = try persistence.viewContext.fetch(request).first {
                member.lastLocationLat = lat
                member.lastLocationLon = lon
                member.lastSeen = Date()
                if let address = brcAddress {
                    member.brcAddress = address
                }
                persistence.save()
                addToSyncQueue(tableName: "CachedMember", recordID: memberID.uuidString, operation: "update")
            }
        } catch {
            print("Failed to update member location: \(error)")
        }
    }
    
    // MARK: - Camp Operations
    
    func fetchCamps() {
        let request: NSFetchRequest<CachedCamp> = CachedCamp.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedCamp.name, ascending: true)]
        
        do {
            camps = try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch camps: \(error)")
        }
    }
    
    @discardableResult
    func saveCamp(
        id: UUID = UUID(),
        name: String,
        locationAddress: String,
        memberCount: Int32 = 0,
        publicKey: Data? = nil
    ) -> CachedCamp {
        let context = persistence.viewContext
        
        // Check if camp already exists
        let request: NSFetchRequest<CachedCamp> = CachedCamp.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        let camp: CachedCamp
        if let existing = try? context.fetch(request).first {
            camp = existing
        } else {
            camp = CachedCamp(context: context)
            camp.id = id
        }
        
        camp.name = name
        camp.locationAddress = locationAddress
        camp.memberCount = memberCount
        camp.publicKey = publicKey
        camp.lastBroadcast = Date()
        
        persistence.save()
        addToSyncQueue(tableName: "CachedCamp", recordID: id.uuidString, operation: "upsert")
        
        return camp
    }
    
    // MARK: - Pending Message Queue (Store-and-Forward)
    
    private func addToPendingQueue(messageID: UUID, recipientID: String, messageType: String, payload: Data?) {
        let context = persistence.viewContext
        let pending = PendingMessage(context: context)
        
        pending.id = messageID
        pending.recipientID = recipientID
        pending.messageType = messageType
        pending.encryptedPayload = payload
        pending.status = "pending"
        pending.attempts = 0
        pending.createdAt = Date()
        
        persistence.save()
        updatePendingCount()
    }
    
    private func removePendingMessage(_ messageID: UUID) {
        let request: NSFetchRequest<PendingMessage> = PendingMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", messageID as CVarArg)
        
        do {
            if let pending = try persistence.viewContext.fetch(request).first {
                persistence.viewContext.delete(pending)
                persistence.save()
                updatePendingCount()
            }
        } catch {
            print("Failed to remove pending message: \(error)")
        }
    }
    
    func getPendingMessages() -> [PendingMessage] {
        let request: NSFetchRequest<PendingMessage> = PendingMessage.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", "pending")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \PendingMessage.createdAt, ascending: true)]
        
        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch pending messages: \(error)")
            return []
        }
    }
    
    func incrementPendingAttempt(_ messageID: UUID) {
        let request: NSFetchRequest<PendingMessage> = PendingMessage.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", messageID as CVarArg)
        
        do {
            if let pending = try persistence.viewContext.fetch(request).first {
                pending.attempts += 1
                pending.lastAttempt = Date()
                
                // Mark as failed after 10 attempts
                if pending.attempts >= 10 {
                    pending.status = "failed"
                }
                
                persistence.save()
            }
        } catch {
            print("Failed to increment pending attempt: \(error)")
        }
    }
    
    private func updatePendingCount() {
        let request: NSFetchRequest<PendingMessage> = PendingMessage.fetchRequest()
        request.predicate = NSPredicate(format: "status == %@", "pending")
        
        do {
            pendingMessageCount = try persistence.viewContext.count(for: request)
        } catch {
            print("Failed to count pending messages: \(error)")
        }
    }
    
    // MARK: - Sync Queue Operations
    
    private func addToSyncQueue(tableName: String, recordID: String, operation: String) {
        let context = persistence.viewContext
        let item = SyncQueueItem(context: context)
        
        item.id = UUID()
        item.tableName = tableName
        item.recordID = recordID
        item.operation = operation
        item.createdAt = Date()
        item.isSynced = false
        
        persistence.save()
    }
    
    func getUnsyncedItems() -> [SyncQueueItem] {
        let request: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == NO")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SyncQueueItem.createdAt, ascending: true)]
        
        do {
            return try persistence.viewContext.fetch(request)
        } catch {
            print("Failed to fetch unsynced items: \(error)")
            return []
        }
    }
    
    func markSynced(_ itemID: UUID) {
        let request: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)
        
        do {
            if let item = try persistence.viewContext.fetch(request).first {
                item.isSynced = true
                persistence.save()
            }
        } catch {
            print("Failed to mark item synced: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupExpiredMessages() {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.predicate = NSPredicate(format: "expiresAt != nil AND expiresAt < %@", Date() as NSDate)
        
        do {
            let expired = try persistence.viewContext.fetch(request)
            for message in expired {
                persistence.viewContext.delete(message)
            }
            persistence.save()
        } catch {
            print("Failed to cleanup expired messages: \(error)")
        }
    }
    
    func cleanupOldSyncItems(olderThan days: Int = 7) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let request: NSFetchRequest<SyncQueueItem> = SyncQueueItem.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == YES AND createdAt < %@", cutoff as NSDate)
        
        do {
            let old = try persistence.viewContext.fetch(request)
            for item in old {
                persistence.viewContext.delete(item)
            }
            persistence.save()
        } catch {
            print("Failed to cleanup old sync items: \(error)")
        }
    }
}
