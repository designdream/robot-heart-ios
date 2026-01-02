import CoreData
import Foundation

// MARK: - Persistence Controller
/// Manages the Core Data stack for offline-first data persistence
/// Supports local SQLite storage with optional CloudKit sync
class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    @Published var isLoaded = false
    @Published var loadError: Error?
    
    // Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        // Add sample data for previews
        for i in 0..<5 {
            let message = CachedMessage(context: viewContext)
            message.id = UUID()
            message.senderID = "user-\(i)"
            message.senderName = "User \(i)"
            message.recipientID = "me"
            message.content = "Sample message \(i)"
            message.timestamp = Date().addingTimeInterval(Double(-i * 3600))
            message.isDelivered = i % 2 == 0
            message.isRead = i % 3 == 0
            message.messageType = "text"
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Preview save error: \(error)")
        }
        
        return controller
    }()
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "RobotHeartData")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure for better performance
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentHistoryTrackingKey
        )
        container.persistentStoreDescriptions.first?.setOption(
            true as NSNumber,
            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey
        )
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                self?.loadError = error
            } else {
                print("Core Data loaded successfully: \(description.url?.absoluteString ?? "unknown")")
                self?.isLoaded = true
            }
        }
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Context Management
    
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    /// Creates a new background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Performs a background task
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }
    
    // MARK: - Save Operations
    
    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
    
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save background context: \(error)")
        }
    }
}
