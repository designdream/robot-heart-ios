import Foundation
import LocalAuthentication

// MARK: - Biometric Auth Manager
/// Manages biometric authentication (Face ID / Touch ID) for identity verification.
///
/// ## Design Philosophy
/// Biometric authentication provides strong identity verification that works
/// completely offline - perfect for Burning Man's harsh environment where
/// internet connectivity is unreliable.
///
/// ## Key Features
/// - **Offline-First**: Face ID/Touch ID works without any network
/// - **Default On**: Biometrics enabled by default for security
/// - **User Control**: Can be disabled in settings if needed
/// - **Graceful Fallback**: Falls back to passcode if biometrics unavailable
///
/// ## Privacy
/// - Biometric data never leaves the device (Secure Enclave)
/// - Apple cannot access Face ID data
/// - Works in airplane mode, disaster scenarios, etc.
///
/// ## Usage
/// ```swift
/// BiometricAuthManager.shared.authenticate { success in
///     if success {
///         // User verified
///     }
/// }
/// ```
class BiometricAuthManager: ObservableObject {
    static let shared = BiometricAuthManager()
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var biometricType: BiometricType = .none
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: "biometricAuthEnabled")
        }
    }
    @Published var requireAuthOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(requireAuthOnLaunch, forKey: "requireAuthOnLaunch")
        }
    }
    @Published var lastAuthDate: Date?
    @Published var authError: String?
    
    // MARK: - Private Properties
    
    private let context = LAContext()
    private let authTimeout: TimeInterval = 300 // 5 minutes before re-auth required
    
    // MARK: - Biometric Type
    
    enum BiometricType: String {
        case none = "None"
        case touchID = "Touch ID"
        case faceID = "Face ID"
        case opticID = "Optic ID" // Vision Pro
    }
    
    // MARK: - Initialization
    
    init() {
        // Default to enabled for security
        self.isEnabled = UserDefaults.standard.object(forKey: "biometricAuthEnabled") as? Bool ?? true
        self.requireAuthOnLaunch = UserDefaults.standard.object(forKey: "requireAuthOnLaunch") as? Bool ?? true
        
        // Detect available biometric type
        detectBiometricType()
    }
    
    // MARK: - Biometric Detection
    
    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .touchID:
                biometricType = .touchID
            case .faceID:
                biometricType = .faceID
            case .opticID:
                biometricType = .opticID
            case .none:
                biometricType = .none
            @unknown default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    /// Check if biometric authentication is available on this device
    var isBiometricAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    /// Check if any authentication (biometric or passcode) is available
    var isAuthenticationAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    // MARK: - Authentication
    
    /// Authenticate user with biometrics (or passcode fallback)
    /// - Parameters:
    ///   - reason: The reason shown to user for authentication
    ///   - allowPasscode: Whether to allow passcode as fallback
    ///   - completion: Called with success/failure result
    func authenticate(
        reason: String = "Verify your identity",
        allowPasscode: Bool = true,
        completion: @escaping (Bool) -> Void
    ) {
        // Skip if disabled
        guard isEnabled else {
            isAuthenticated = true
            completion(true)
            return
        }
        
        // Check if recently authenticated
        if let lastAuth = lastAuthDate,
           Date().timeIntervalSince(lastAuth) < authTimeout {
            isAuthenticated = true
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        let policy: LAPolicy = allowPasscode ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics
        
        if context.canEvaluatePolicy(policy, error: &error) {
            context.evaluatePolicy(policy, localizedReason: reason) { [weak self] success, authError in
                DispatchQueue.main.async {
                    if success {
                        self?.isAuthenticated = true
                        self?.lastAuthDate = Date()
                        self?.authError = nil
                        completion(true)
                    } else {
                        self?.isAuthenticated = false
                        self?.authError = authError?.localizedDescription
                        completion(false)
                    }
                }
            }
        } else {
            // Biometrics not available - allow access if passcode fallback disabled
            DispatchQueue.main.async {
                self.authError = error?.localizedDescription
                if !allowPasscode {
                    // No biometrics and no passcode fallback - deny
                    completion(false)
                } else {
                    // Device has no security - allow (user's choice)
                    self.isAuthenticated = true
                    completion(true)
                }
            }
        }
    }
    
    /// Authenticate with async/await
    @MainActor
    func authenticate(reason: String = "Verify your identity", allowPasscode: Bool = true) async -> Bool {
        await withCheckedContinuation { continuation in
            authenticate(reason: reason, allowPasscode: allowPasscode) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Reset authentication state (e.g., when app goes to background)
    func resetAuthentication() {
        isAuthenticated = false
    }
    
    /// Extend the authentication session
    func extendSession() {
        if isAuthenticated {
            lastAuthDate = Date()
        }
    }
    
    // MARK: - Sensitive Operations
    
    /// Authenticate before performing a sensitive operation
    func authenticateForSensitiveOperation(
        operation: String,
        completion: @escaping (Bool) -> Void
    ) {
        authenticate(
            reason: "Authenticate to \(operation)",
            allowPasscode: true,
            completion: completion
        )
    }
    
    /// Check if user needs to re-authenticate
    var needsReauthentication: Bool {
        guard isEnabled else { return false }
        guard let lastAuth = lastAuthDate else { return true }
        return Date().timeIntervalSince(lastAuth) >= authTimeout
    }
}
