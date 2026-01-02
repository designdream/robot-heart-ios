import Foundation
import Combine
import SwiftUI

/// Manages user roles and feature flags throughout the app.
///
/// Key responsibilities:
/// - Track the user's actual role
/// - Allow admins to switch to other roles for testing
/// - Provide feature flag checks for UI components
/// - Persist role state across app launches
///
/// ## Usage
/// ```swift
/// @EnvironmentObject var roleManager: RoleManager
///
/// if roleManager.canAccess(.campShifts) {
///     ShiftsView()
/// }
/// ```
class RoleManager: ObservableObject {
    static let shared = RoleManager()
    
    // MARK: - Published Properties
    
    /// The user's actual assigned role
    @Published var actualRole: UserRole {
        didSet { saveState() }
    }
    
    /// The role currently being viewed (for admin testing)
    /// If nil, uses actualRole
    @Published var simulatedRole: UserRole? {
        didSet { saveState() }
    }
    
    /// Whether admin is currently simulating another role
    @Published var isSimulatingRole: Bool = false
    
    /// Current community memberships
    @Published var memberships: [Membership] = []
    
    /// Active community (the one currently being viewed)
    @Published var activeCommunityID: UUID?
    
    // MARK: - Computed Properties
    
    /// The effective role (simulated if admin is testing, otherwise actual)
    var effectiveRole: UserRole {
        if actualRole == .admin, let simulated = simulatedRole {
            return simulated
        }
        return actualRole
    }
    
    /// Whether the user is an admin (regardless of simulation)
    var isAdmin: Bool {
        actualRole == .admin
    }
    
    /// Whether the user can access admin features
    var canAccessAdminFeatures: Bool {
        actualRole == .admin
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let roleKey = "userRole"
    private let simulatedRoleKey = "simulatedRole"
    private let membershipsKey = "memberships"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Load saved role or default to fan
        if let roleString = userDefaults.string(forKey: roleKey),
           let role = UserRole(rawValue: roleString) {
            actualRole = role
        } else {
            actualRole = .fan
        }
        
        // Load simulated role if any
        if let simString = userDefaults.string(forKey: simulatedRoleKey),
           let simRole = UserRole(rawValue: simString) {
            simulatedRole = simRole
            isSimulatingRole = true
        }
        
        loadMemberships()
    }
    
    // MARK: - Role Management
    
    /// Set the user's actual role (called during onboarding or by server)
    func setRole(_ role: UserRole) {
        actualRole = role
        // Clear simulation when role changes
        if role != .admin {
            clearSimulation()
        }
    }
    
    /// Simulate a different role (admin only)
    func simulateRole(_ role: UserRole) {
        guard actualRole == .admin else { return }
        simulatedRole = role
        isSimulatingRole = true
    }
    
    /// Clear role simulation and return to actual role
    func clearSimulation() {
        simulatedRole = nil
        isSimulatingRole = false
        userDefaults.removeObject(forKey: simulatedRoleKey)
    }
    
    /// Cycle through roles (for quick testing)
    func cycleToNextRole() {
        guard actualRole == .admin else { return }
        
        let allRoles = UserRole.allCases
        let currentIndex = allRoles.firstIndex(of: effectiveRole) ?? 0
        let nextIndex = (currentIndex + 1) % allRoles.count
        simulateRole(allRoles[nextIndex])
    }
    
    // MARK: - Feature Access
    
    /// Check if a feature is accessible with current role
    func canAccess(_ feature: FeatureFlags.Feature) -> Bool {
        FeatureFlags.isEnabled(feature, for: effectiveRole)
    }
    
    /// Get all available features for current role
    var availableFeatures: [FeatureFlags.Feature] {
        FeatureFlags.availableFeatures(for: effectiveRole)
    }
    
    /// Get features grouped by category
    var featuresByCategory: [FeatureFlags.FeatureCategory: [FeatureFlags.Feature]] {
        FeatureFlags.featuresByCategory(for: effectiveRole)
    }
    
    // MARK: - Membership Management
    
    /// Add a membership
    func addMembership(_ membership: Membership) {
        memberships.append(membership)
        saveMemberships()
    }
    
    /// Update membership role
    func updateMembershipRole(membershipID: UUID, newRole: UserRole) {
        if let index = memberships.firstIndex(where: { $0.id == membershipID }) {
            memberships[index].role = newRole
            saveMemberships()
        }
    }
    
    /// Get membership for a community
    func membership(for communityID: UUID) -> Membership? {
        memberships.first { $0.communityID == communityID }
    }
    
    /// Get role in a specific community
    func role(in communityID: UUID) -> UserRole? {
        membership(for: communityID)?.role
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        userDefaults.set(actualRole.rawValue, forKey: roleKey)
        if let simRole = simulatedRole {
            userDefaults.set(simRole.rawValue, forKey: simulatedRoleKey)
        }
    }
    
    private func loadMemberships() {
        if let data = userDefaults.data(forKey: membershipsKey),
           let decoded = try? JSONDecoder().decode([Membership].self, from: data) {
            memberships = decoded
        }
    }
    
    private func saveMemberships() {
        if let encoded = try? JSONEncoder().encode(memberships) {
            userDefaults.set(encoded, forKey: membershipsKey)
        }
    }
}

// MARK: - SwiftUI View Modifiers

/// View modifier that hides content if feature is not accessible
struct FeatureGated: ViewModifier {
    @EnvironmentObject var roleManager: RoleManager
    let feature: FeatureFlags.Feature
    
    func body(content: Content) -> some View {
        if roleManager.canAccess(feature) {
            content
        }
    }
}

/// View modifier that shows content only for specific roles
struct RoleGated: ViewModifier {
    @EnvironmentObject var roleManager: RoleManager
    let minimumRole: UserRole
    
    func body(content: Content) -> some View {
        if roleManager.effectiveRole.hasPermission(of: minimumRole) {
            content
        }
    }
}

extension View {
    /// Only show this view if the feature is accessible
    func requiresFeature(_ feature: FeatureFlags.Feature) -> some View {
        modifier(FeatureGated(feature: feature))
    }
    
    /// Only show this view for users with at least this role
    func requiresRole(_ role: UserRole) -> some View {
        modifier(RoleGated(minimumRole: role))
    }
}

// MARK: - Preview Helpers

extension RoleManager {
    static var previewFan: RoleManager {
        let manager = RoleManager()
        manager.actualRole = .fan
        return manager
    }
    
    static var previewVolunteer: RoleManager {
        let manager = RoleManager()
        manager.actualRole = .volunteer
        return manager
    }
    
    static var previewCampMember: RoleManager {
        let manager = RoleManager()
        manager.actualRole = .campMember
        return manager
    }
    
    static var previewLead: RoleManager {
        let manager = RoleManager()
        manager.actualRole = .lead
        return manager
    }
    
    static var previewAdmin: RoleManager {
        let manager = RoleManager()
        manager.actualRole = .admin
        return manager
    }
}
