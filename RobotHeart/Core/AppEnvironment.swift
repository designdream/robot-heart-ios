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
    
    /// Primary long-range mesh network (LoRa) - Orchestrator for all Meshtastic services
    @Published var meshtastic: MeshtasticOrchestrator
    
    /// Legacy compatibility shim for views still using MeshtasticManager
    /// DEPRECATED: Use `meshtastic` (MeshtasticOrchestrator) instead
    @Published var meshtasticLegacy: MeshtasticManager
    
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
    
    // MARK: - QR Code Services
    
    /// QR code scanning and generation
    @Published var qrCodeManager: QRCodeManager
    
    // MARK: - Data Management
    
    /// Local data storage and caching
    @Published var localData: LocalDataManager
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        
        // Initialize core services first (use local vars to avoid self access issues)
        let locationManager = LocationManager()
        let meshtasticOrchestrator = MeshtasticOrchestrator(locationManager: locationManager)
        let meshtasticManager = MeshtasticManager(orchestrator: meshtasticOrchestrator)
        let bleMeshManager = BLEMeshManager.shared
        let cloudSyncService = CloudSyncService()
        
        self.location = locationManager
        self.meshtastic = meshtasticOrchestrator
        self.meshtasticLegacy = meshtasticManager
        self.bleMesh = bleMeshManager
        self.localData = LocalDataManager.shared
        self.cloudSync = cloudSyncService
        
        // Initialize network orchestrator (depends on cloudSync, meshtastic, and bleMesh)
        let networkOrchestratorInstance = NetworkOrchestrator(
            cloudSync: cloudSyncService,
            meshtasticOrchestrator: meshtasticOrchestrator,
            bleMesh: bleMeshManager
        )
        self.networkOrchestrator = networkOrchestratorInstance
        
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
        
        // Initialize QR code manager (depends on networkOrchestrator)
        self.qrCodeManager = QRCodeManager(networkOrchestrator: networkOrchestratorInstance)
    }
    
    // MARK: - Configuration Updates
    
    /// Reload CloudSyncService with updated S3 credentials from Keychain
    func updateS3Credentials() {
        // Re-initialize CloudSyncService to pick up new credentials
        self.cloudSync = CloudSyncService()
        
        // Update NetworkOrchestrator with new CloudSyncService
        self.networkOrchestrator = NetworkOrchestrator(
            cloudSync: cloudSync,
            meshtasticOrchestrator: meshtastic,
            bleMesh: bleMesh
        )
        
        print("🔄 [AppEnvironment] Reloaded with updated S3 credentials")
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
        
        // Gateway node relay is handled automatically by CloudSyncService polling
        
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
    @MainActor static let defaultValue = AppEnvironment()
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
