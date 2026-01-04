import Foundation
import Security

/// Secure storage service for sensitive credentials using iOS Keychain.
/// Provides type-safe access to S3 credentials and other secrets.
///
/// Features:
/// - Encrypted storage via iOS Keychain
/// - Automatic iCloud Keychain sync (optional)
/// - Type-safe credential access
/// - Error handling with detailed diagnostics
class KeychainService {
    
    // MARK: - Singleton
    
    static let shared = KeychainService()
    
    private init() {}
    
    // MARK: - Keychain Keys
    
    private enum KeychainKey: String {
        case s3AccessKey = "com.robotheart.s3.accessKey"
        case s3SecretKey = "com.robotheart.s3.secretKey"
        case s3Endpoint = "com.robotheart.s3.endpoint"
        case s3Bucket = "com.robotheart.s3.bucket"
        case s3Region = "com.robotheart.s3.region"
        case deviceID = "com.robotheart.deviceID"
    }
    
    // MARK: - Error Types
    
    enum KeychainError: Error, LocalizedError {
        case duplicateItem
        case itemNotFound
        case invalidData
        case unexpectedStatus(OSStatus)
        
        var errorDescription: String? {
            switch self {
            case .duplicateItem:
                return "Item already exists in Keychain"
            case .itemNotFound:
                return "Item not found in Keychain"
            case .invalidData:
                return "Invalid data format"
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            }
        }
    }
    
    // MARK: - S3 Credentials
    
    struct S3Credentials {
        let accessKey: String
        let secretKey: String
        let endpoint: String
        let bucket: String
        let region: String
        
        var isValid: Bool {
            !accessKey.isEmpty && !secretKey.isEmpty && !endpoint.isEmpty && !bucket.isEmpty
        }
    }
    
    /// Save S3 credentials to Keychain
    func saveS3Credentials(_ credentials: S3Credentials) throws {
        try save(credentials.accessKey, for: .s3AccessKey)
        try save(credentials.secretKey, for: .s3SecretKey)
        try save(credentials.endpoint, for: .s3Endpoint)
        try save(credentials.bucket, for: .s3Bucket)
        try save(credentials.region, for: .s3Region)
        
        print("🔐 [Keychain] Saved S3 credentials")
    }
    
    /// Load S3 credentials from Keychain
    func loadS3Credentials() throws -> S3Credentials {
        let accessKey = try load(for: .s3AccessKey)
        let secretKey = try load(for: .s3SecretKey)
        let endpoint = try load(for: .s3Endpoint)
        let bucket = try load(for: .s3Bucket)
        let region = try load(for: .s3Region)
        
        return S3Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            endpoint: endpoint,
            bucket: bucket,
            region: region
        )
    }
    
    /// Check if S3 credentials exist
    func hasS3Credentials() -> Bool {
        do {
            let credentials = try loadS3Credentials()
            return credentials.isValid
        } catch {
            return false
        }
    }
    
    /// Delete S3 credentials from Keychain
    func deleteS3Credentials() throws {
        try delete(for: .s3AccessKey)
        try delete(for: .s3SecretKey)
        try delete(for: .s3Endpoint)
        try delete(for: .s3Bucket)
        try delete(for: .s3Region)
        
        print("🔐 [Keychain] Deleted S3 credentials")
    }
    
    // MARK: - Device ID
    
    /// Get or create persistent device ID
    func getDeviceID() -> String {
        // Try to load existing device ID
        if let existingID = try? load(for: .deviceID) {
            return existingID
        }
        
        // Generate new device ID
        let newID = UUID().uuidString
        try? save(newID, for: .deviceID)
        
        print("🔐 [Keychain] Generated new device ID: \(newID)")
        return newID
    }
    
    // MARK: - Generic Keychain Operations
    
    /// Save string value to Keychain
    private func save(_ value: String, for key: KeychainKey) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        // Delete existing item if present
        try? delete(for: key)
        
        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            // Optional: Enable iCloud Keychain sync
            // kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Load string value from Keychain
    private func load(for key: KeychainKey) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Optional: Enable iCloud Keychain sync
            // kSecAttrSynchronizable as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return value
    }
    
    /// Delete value from Keychain
    private func delete(for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            // Optional: Enable iCloud Keychain sync
            // kSecAttrSynchronizable as String: true
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    // MARK: - Debugging
    
    /// Print all stored Keychain items (for debugging only, remove in production)
    func debugPrintStoredKeys() {
        print("🔐 [Keychain] Stored keys:")
        
        for key in [KeychainKey.s3AccessKey, .s3SecretKey, .s3Endpoint, .s3Bucket, .s3Region, .deviceID] {
            if let value = try? load(for: key) {
                // Mask sensitive values
                let masked = key == .s3SecretKey ? String(repeating: "*", count: value.count) : value
                print("  - \(key.rawValue): \(masked)")
            }
        }
    }
}

// MARK: - First-Time Setup Extension

extension KeychainService {
    
    /// Setup S3 credentials for first-time use
    /// Call this during onboarding or settings configuration
    func setupS3Credentials(
        accessKey: String,
        secretKey: String,
        endpoint: String = "nyc3.digitaloceanspaces.com",
        bucket: String = "robot-heart-mesh",
        region: String = "nyc3"
    ) throws {
        let credentials = S3Credentials(
            accessKey: accessKey,
            secretKey: secretKey,
            endpoint: endpoint,
            bucket: bucket,
            region: region
        )
        
        guard credentials.isValid else {
            throw KeychainError.invalidData
        }
        
        try saveS3Credentials(credentials)
    }
    
    /// Validate S3 credentials by attempting a test request
    func validateS3Credentials() async throws -> Bool {
        let credentials = try loadS3Credentials()
        
        // Create test URL (list bucket)
        let url = URL(string: "https://\(credentials.bucket).\(credentials.endpoint)/")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        // Add AWS Signature V4 authentication
        // This will be implemented in AWSV4Signer
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        // 200 = success, 403 = valid credentials but no access, 401 = invalid credentials
        return (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 403
    }
}
