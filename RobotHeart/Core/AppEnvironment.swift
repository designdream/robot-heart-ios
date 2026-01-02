import SwiftUI
import CoreData

/// Centralized application environment that holds all services and managers.
/// This replaces the previous pattern of injecting 20+ individual managers into the environment.
///
/// Benefits:
/// - Single point of dependency management
/// - Explicit dependencies (no hidden singletons)
/// - Easier to test (can inject mock environment)
/// - Clear service lifecycle management
@MainActor
class AppEnvironment: ObservableObject {
    
    // MARK: - Core Services
    
    /// Persistence layer (Core Data)
    let persistenceController: PersistenceController
    
    // MARK: - Network & Communication
    
    /// Primary long-range mesh network (LoRa)
    @Published var meshtastic: MeshtasticManager
    
    /// Short-range presence detection and high-bandwidth transfers
    @Published var bleMesh: BLEMeshManager
    
    /// Orchestrates which network to use for each task
    @Published var networkOrchestrator: NetworkOrchestrator
    
    /// Message queue for offline-first messaging
    @Published var messageQueue: MessageQueueManager
    
    /// Cloud sync for gateway nodes (Digital Ocean S3)
    @Published var cloudSync: CloudSyncService
    
    /// Camp network discovery
    @Published var campNetwork: CampNetworkManager
    
    // MARK: - Location & Safety
    
    /// GPS location tracking and sharing
    @Published var location: LocationManager
    
    /// Emergency alerts and SOS
    @Published var emergency: EmergencyManager
    
    /// Safety check-ins
    @Published var checkIn: CheckInManager
    
    // MARK: - Camp Management
    
    /// Shift scheduling and management
    @Published var shifts: ShiftManager
    
    /// Shift blocking and trading
    @Published var shiftBlocks: ShiftBlockManager
    
    /// Draft system for shift assignments
    @Published var draft: DraftManager
    
    /// Camp layout and spatial organization
    @Published var campLayout: CampLayoutManager
    
    /// Task management
    @Published var tasks: TaskManager
    
    // MARK: - Social & Communication
    
    /// User profiles
    @Published var profiles: ProfileManager
    
    /// Social interactions and relationships
    @Published var social: SocialManager
    
    /// Social capital and economy
    @Published var economy: EconomyManager
    
    /// Channel-based messaging
    @Published var channels: ChannelManager
    
    /// Announcements
    @Published var announcements: AnnouncementManager
    
    // MARK: - Security
    
    /// Biometric authentication
    @Published var biometricAuth: BiometricAuthManager
    
    // MARK: - Data Management
    
    /// Local data storage and caching
    @Published var localData: LocalDataManager
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        
        // Initialize core services first
        self.meshtastic = MeshtasticManager()
        self.bleMesh = BLEMeshManager.shared
        self.location = LocationManager()
        self.localData = LocalDataManager.shared
        
        // Initialize cloud sync service
        self.cloudSync = CloudSyncService()
        
        // Initialize network orchestrator (depends on cloudSync, meshtastic, and bleMesh)
        self.networkOrchestrator = NetworkOrchestrator(
            cloudSync: cloudSync,
            meshtastic: meshtastic,
            bleMesh: bleMesh
        )
        
        // Initialize messaging services
        self.messageQueue = MessageQueueManager.shared
        self.campNetwork = CampNetworkManager.shared
        
        // Initialize location and safety services
        self.emergency = EmergencyManager()
        self.checkIn = CheckInManager()
        
        // Initialize camp management services
        self.shifts = ShiftManager()
        self.shiftBlocks = ShiftBlockManager()
        self.draft = DraftManager()
        self.campLayout = CampLayoutManager()
        self.tasks = TaskManager()
        
        // Initialize social services
        self.profiles = ProfileManager()
        self.social = SocialManager()
        self.economy = EconomyManager()
        self.channels = ChannelManager()
        self.announcements = AnnouncementManager()
        
        // Initialize security
        self.biometricAuth = BiometricAuthManager.shared
    }
    
    // MARK: - Lifecycle Methods
    
    /// Start all services that need to run in the background
    func startServices() {
        let userID = UserDefaults.standard.string(forKey: "userID") ?? UUID().uuidString
        let userName = profiles.myProfile.displayName
        
        // Save user ID if not set
        if UserDefaults.standard.string(forKey: "userID") == nil {
            UserDefaults.standard.set(userID, forKey: "userID")
        }
        UserDefaults.standard.set(userName, forKey: "userName")
        
        // Start network services via orchestrator
        networkOrchestrator.startNetworking(userID: userID, userName: userName)
        
        // Start camp network discovery
        campNetwork.startDiscovery()
        
        // Setup gateway node relay if online
        if cloudSync.isGatewayNode {
            cloudSync.relayFromCloud()
        }
        
        // Cleanup old data
        localData.cleanupExpiredMessages()
        localData.cleanupOldSyncItems()
        
        // Request notification permissions
        shifts.requestNotificationPermissions()
    }
    
    /// Stop all services (called when app goes to background)
    func stopServices() {
        networkOrchestrator.stopNetworking()
    }
    
    /// Pause services (called when app becomes inactive)
    func pauseServices() {
        // Reduce power consumption while inactive
        networkOrchestrator.pauseNetworking()
    }
    
    /// Resume services (called when app becomes active)
    func resumeServices() {
        networkOrchestrator.resumeNetworking()
    }
}

// MARK: - Environment Key

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppEnvironment()
}

extension EnvironmentValues {
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Inject the app environment into the view hierarchy
    func withAppEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.managedObjectContext, environment.persistenceController.viewContext)
            .environmentObject(environment)
            .environmentObject(environment.meshtastic)
            .environmentObject(environment.location)
            .environmentObject(environment.shifts)
            .environmentObject(environment.emergency)
            .environmentObject(environment.announcements)
            .environmentObject(environment.checkIn)
            .environmentObject(environment.economy)
            .environmentObject(environment.draft)
            .environmentObject(environment.shiftBlocks)
            .environmentObject(environment.profiles)
            .environmentObject(environment.social)
            .environmentObject(environment.tasks)
            .environmentObject(environment.campLayout)
            .environmentObject(environment.channels)
            .environmentObject(environment.localData)
            .environmentObject(environment.bleMesh)
            .environmentObject(environment.messageQueue)
            .environmentObject(environment.cloudSync)
            .environmentObject(environment.campNetwork)
            .environmentObject(environment.biometricAuth)
    }
}
