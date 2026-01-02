import Foundation
import CryptoKit
import LocalAuthentication

// MARK: - Privacy Protection System
/// Comprehensive privacy protection for sensitive data.
/// Designed for scenarios where devices may be seized at borders or by authorities.
///
/// Key Features:
/// - Local-first storage (like WhatsApp)
/// - Optional encrypted cloud backup
/// - Panic mode for border crossings
/// - Plausible deniability
/// - Secure deletion

// MARK: - Storage Mode

enum StorageMode: String, Codable, CaseIterable {
    case localOnly = "Local Only"
    case localWithBackup = "Local + Encrypted Backup"
    case distributed = "Distributed (P2P)"
    
    var description: String {
        switch self {
        case .localOnly:
            return "All data stays on your device. Most private, but no recovery if device is lost."
        case .localWithBackup:
            return "Data encrypted and backed up to cloud. You control the encryption key."
        case .distributed:
            return "Data distributed across trusted peers. Most resilient, requires network."
        }
    }
    
    var icon: String {
        switch self {
        case .localOnly: return "iphone"
        case .localWithBackup: return "icloud.and.arrow.up"
        case .distributed: return "network"
        }
    }
}

// MARK: - Privacy Level

enum PrivacyLevel: Int, Codable, CaseIterable, Comparable {
    case standard = 0      // Normal operation
    case enhanced = 1      // Extra encryption, shorter retention
    case maximum = 2       // Paranoid mode, minimal data retention
    case panic = 3         // Border crossing / emergency wipe
    
    var label: String {
        switch self {
        case .standard: return "Standard"
        case .enhanced: return "Enhanced"
        case .maximum: return "Maximum"
        case .panic: return "Panic Mode"
        }
    }
    
    var description: String {
        switch self {
        case .standard:
            return "Normal privacy protections. Messages encrypted, standard retention."
        case .enhanced:
            return "Extra encryption layers. Messages auto-delete after 7 days."
        case .maximum:
            return "Paranoid mode. Messages auto-delete after 24 hours. No cloud sync."
        case .panic:
            return "Emergency mode. Sensitive data hidden or wiped. Use at borders."
        }
    }
    
    var messageRetentionDays: Int? {
        switch self {
        case .standard: return nil  // Keep forever
        case .enhanced: return 7
        case .maximum: return 1
        case .panic: return 0  // Immediate wipe
        }
    }
    
    static func < (lhs: PrivacyLevel, rhs: PrivacyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Panic Mode Actions

struct PanicModeActions {
    
    /// Actions to take when entering panic mode
    static func activate() {
        // 1. Hide sensitive conversations
        hideSensitiveConversations()
        
        // 2. Clear message cache
        clearMessageCache()
        
        // 3. Disable biometric unlock temporarily
        disableBiometricUnlock()
        
        // 4. Show decoy content
        enableDecoyMode()
        
        // 5. Log panic activation (encrypted, for later review)
        logPanicActivation()
    }
    
    /// Actions to take when exiting panic mode
    static func deactivate(with pin: String) -> Bool {
        guard verifyRecoveryPin(pin) else { return false }
        
        // 1. Restore hidden conversations
        restoreSensitiveConversations()
        
        // 2. Re-enable biometric unlock
        enableBiometricUnlock()
        
        // 3. Disable decoy mode
        disableDecoyMode()
        
        return true
    }
    
    // MARK: - Private Methods
    
    private static func hideSensitiveConversations() {
        // Move sensitive data to encrypted hidden partition
        // Conversations marked as "sensitive" are hidden
        UserDefaults.standard.set(true, forKey: "panicModeActive")
    }
    
    private static func restoreSensitiveConversations() {
        UserDefaults.standard.set(false, forKey: "panicModeActive")
    }
    
    private static func clearMessageCache() {
        // Clear in-memory message cache
        // Does NOT delete persisted encrypted messages
    }
    
    private static func disableBiometricUnlock() {
        UserDefaults.standard.set(false, forKey: "biometricEnabled")
    }
    
    private static func enableBiometricUnlock() {
        UserDefaults.standard.set(true, forKey: "biometricEnabled")
    }
    
    private static func enableDecoyMode() {
        // Show innocent-looking content instead of real data
        UserDefaults.standard.set(true, forKey: "decoyModeActive")
    }
    
    private static func disableDecoyMode() {
        UserDefaults.standard.set(false, forKey: "decoyModeActive")
    }
    
    private static func verifyRecoveryPin(_ pin: String) -> Bool {
        // Verify against stored hash
        guard let storedHash = UserDefaults.standard.string(forKey: "recoveryPinHash") else {
            return false
        }
        let inputHash = SHA256.hash(data: Data(pin.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return inputHash == storedHash
    }
    
    private static func logPanicActivation() {
        // Encrypted log for later review
        let log = PanicLog(
            timestamp: Date(),
            location: nil,  // Don't log location during panic
            trigger: .manual
        )
        // Store encrypted
    }
}

// MARK: - Panic Log

struct PanicLog: Codable {
    let timestamp: Date
    let location: String?
    let trigger: PanicTrigger
    
    enum PanicTrigger: String, Codable {
        case manual = "Manual activation"
        case duress = "Duress PIN entered"
        case geofence = "Entered restricted area"
        case timeout = "Extended inactivity"
    }
}

// MARK: - Secure Storage Manager

class SecureStorageManager: ObservableObject {
    static let shared = SecureStorageManager()
    
    @Published var storageMode: StorageMode = .localOnly
    @Published var privacyLevel: PrivacyLevel = .standard
    @Published var isPanicModeActive: Bool = false
    @Published var isDecoyModeActive: Bool = false
    
    // Storage stats
    @Published var localStorageUsed: Int64 = 0
    @Published var cloudStorageUsed: Int64 = 0
    @Published var peerStorageAvailable: Int64 = 0
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    // MARK: - Settings Management
    
    func loadSettings() {
        if let modeString = userDefaults.string(forKey: "storageMode"),
           let mode = StorageMode(rawValue: modeString) {
            storageMode = mode
        }
        
        privacyLevel = PrivacyLevel(rawValue: userDefaults.integer(forKey: "privacyLevel")) ?? .standard
        isPanicModeActive = userDefaults.bool(forKey: "panicModeActive")
        isDecoyModeActive = userDefaults.bool(forKey: "decoyModeActive")
    }
    
    func saveSettings() {
        userDefaults.set(storageMode.rawValue, forKey: "storageMode")
        userDefaults.set(privacyLevel.rawValue, forKey: "privacyLevel")
    }
    
    // MARK: - Panic Mode
    
    func activatePanicMode() {
        PanicModeActions.activate()
        isPanicModeActive = true
        isDecoyModeActive = true
    }
    
    func deactivatePanicMode(pin: String) -> Bool {
        if PanicModeActions.deactivate(with: pin) {
            isPanicModeActive = false
            isDecoyModeActive = false
            return true
        }
        return false
    }
    
    // MARK: - Recovery PIN
    
    func setRecoveryPin(_ pin: String) {
        let hash = SHA256.hash(data: Data(pin.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        userDefaults.set(hash, forKey: "recoveryPinHash")
    }
    
    func hasRecoveryPin() -> Bool {
        userDefaults.string(forKey: "recoveryPinHash") != nil
    }
    
    // MARK: - Duress PIN
    /// A secondary PIN that activates panic mode when entered
    /// Useful if forced to unlock device
    
    func setDuressPin(_ pin: String) {
        let hash = SHA256.hash(data: Data(pin.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        userDefaults.set(hash, forKey: "duressPinHash")
    }
    
    func isDuressPin(_ pin: String) -> Bool {
        guard let storedHash = userDefaults.string(forKey: "duressPinHash") else {
            return false
        }
        let inputHash = SHA256.hash(data: Data(pin.utf8)).compactMap { String(format: "%02x", $0) }.joined()
        return inputHash == storedHash
    }
    
    // MARK: - Secure Deletion
    
    func secureDeleteAllData() {
        // Overwrite data before deletion
        // Multiple passes for SSD wear leveling
        
        // 1. Delete messages
        // 2. Delete contacts
        // 3. Delete social capital history
        // 4. Clear keychain
        // 5. Reset user defaults
        
        // This is a destructive operation - require confirmation
    }
    
    func secureDeleteConversation(_ conversationID: String) {
        // Securely delete a single conversation
    }
    
    // MARK: - Storage Calculation
    
    func calculateStorageUsage() {
        // Calculate local storage used by app
        // This helps users understand their data footprint
    }
}

// MARK: - Message Encryption

struct MessageEncryption {
    
    /// Encrypt a message for storage
    static func encrypt(_ content: String, with key: SymmetricKey) -> Data? {
        guard let data = content.data(using: .utf8) else { return nil }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            return sealedBox.combined
        } catch {
            print("Encryption failed: \(error)")
            return nil
        }
    }
    
    /// Decrypt a message from storage
    static func decrypt(_ data: Data, with key: SymmetricKey) -> String? {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption failed: \(error)")
            return nil
        }
    }
    
    /// Generate a new encryption key
    static func generateKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }
    
    /// Derive key from password
    static func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let derivedKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("RobotHeart".utf8),
            outputByteCount: 32
        )
        return derivedKey
    }
}

// MARK: - Volunteer Cloud Storage

struct VolunteerCloudStorage: Identifiable, Codable {
    let id: UUID
    let volunteerID: String
    let volunteerName: String
    let availableSpace: Int64  // bytes
    let usedSpace: Int64
    let trustLevel: SocialCapital.TrustLevel
    let isOnline: Bool
    let lastSeen: Date
    
    var availableSpaceFormatted: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }
    
    var usedSpaceFormatted: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }
}

// MARK: - Distributed Storage Manager

class DistributedStorageManager: ObservableObject {
    static let shared = DistributedStorageManager()
    
    @Published var volunteers: [VolunteerCloudStorage] = []
    @Published var isVolunteering: Bool = false
    @Published var myVolunteerSpace: Int64 = 0
    @Published var myUsedSpace: Int64 = 0
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSettings()
    }
    
    func loadSettings() {
        isVolunteering = userDefaults.bool(forKey: "isStorageVolunteer")
        myVolunteerSpace = Int64(userDefaults.integer(forKey: "volunteerStorageSpace"))
    }
    
    // MARK: - Volunteer Management
    
    func becomeVolunteer(spaceInGB: Int) {
        isVolunteering = true
        myVolunteerSpace = Int64(spaceInGB) * 1_000_000_000
        userDefaults.set(true, forKey: "isStorageVolunteer")
        userDefaults.set(spaceInGB * 1_000_000_000, forKey: "volunteerStorageSpace")
        
        // Announce to network
        announceVolunteerStatus()
    }
    
    func stopVolunteering() {
        isVolunteering = false
        myVolunteerSpace = 0
        userDefaults.set(false, forKey: "isStorageVolunteer")
        userDefaults.set(0, forKey: "volunteerStorageSpace")
        
        // Notify peers to migrate data
        notifyDataMigration()
    }
    
    private func announceVolunteerStatus() {
        // Broadcast volunteer status to mesh network
    }
    
    private func notifyDataMigration() {
        // Notify peers that they need to migrate data elsewhere
    }
    
    // MARK: - Data Distribution
    
    func storeDistributed(_ data: Data, for userID: String) {
        // Split data into chunks
        // Encrypt each chunk
        // Distribute to multiple volunteers
        // Store chunk locations locally
    }
    
    func retrieveDistributed(for userID: String) -> Data? {
        // Retrieve chunk locations
        // Fetch chunks from volunteers
        // Decrypt and reassemble
        return nil
    }
}

// MARK: - Border Crossing Checklist

struct BorderCrossingChecklist {
    
    /// Recommended actions before crossing a border
    static let preChecklist: [(action: String, icon: String, critical: Bool)] = [
        ("Enable Panic Mode", "exclamationmark.shield.fill", true),
        ("Set Recovery PIN", "key.fill", true),
        ("Set Duress PIN", "hand.raised.fill", false),
        ("Clear message cache", "trash.fill", false),
        ("Disable biometric unlock", "faceid", true),
        ("Note recovery contacts", "person.2.fill", false),
        ("Backup encryption key offline", "doc.text.fill", true),
    ]
    
    /// Actions to take after safely crossing
    static let postChecklist: [(action: String, icon: String)] = [
        ("Enter Recovery PIN", "key.fill"),
        ("Verify data integrity", "checkmark.shield.fill"),
        ("Re-enable biometric unlock", "faceid"),
        ("Check for tampering", "magnifyingglass"),
    ]
}
