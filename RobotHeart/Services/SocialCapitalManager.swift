import Foundation
import Combine
import UIKit

/// Manages social capital - the trust and reputation that persists year-round.
///
/// Social capital represents genuine trust built through consistent participation.
/// Unlike competitive points that reset, this reputation carries across:
/// - Burning Man events
/// - Regional burns
/// - Off-season camping trips
/// - Other community events
///
/// ## Usage
/// ```swift
/// let manager = SocialCapitalManager.shared
/// manager.recordShiftCompleted(points: 15)
/// print(manager.myCapital.trustLevel) // .reliable
/// ```
class SocialCapitalManager: ObservableObject {
    static let shared = SocialCapitalManager()
    
    // MARK: - Published Properties
    @Published var myCapital: SocialCapital
    @Published var trustedNetwork: TrustedNetwork = TrustedNetwork()
    @Published var currentEvent: SocialCapital.EventParticipation?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let capitalKey = "mySocialCapital"
    private let networkKey = "trustedNetwork"
    private let eventKey = "currentEvent"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Load or create social capital
        if let data = userDefaults.data(forKey: capitalKey),
           let capital = try? JSONDecoder().decode(SocialCapital.self, from: data) {
            myCapital = capital
        } else {
            // Create new social capital with device ID
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
            myCapital = SocialCapital(memberID: deviceID, displayName: "New Member")
        }
        
        loadTrustedNetwork()
        loadCurrentEvent()
        
        // Auto-save on changes
        $myCapital
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveCapital() }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Management
    
    /// Start participating in a new event
    func startEvent(name: String, type: SocialCapital.EventParticipation.EventType, year: Int = Calendar.current.component(.year, from: Date())) {
        let event = SocialCapital.EventParticipation(eventName: name, eventType: type, year: year)
        currentEvent = event
        myCapital.startEvent(event)
        saveCurrentEvent()
        saveCapital()
    }
    
    /// End the current event
    func endCurrentEvent() {
        guard var event = currentEvent else { return }
        // Update the event in history with final stats
        if let index = myCapital.eventHistory.firstIndex(where: { $0.id == event.id }) {
            myCapital.eventHistory[index] = event
        }
        currentEvent = nil
        userDefaults.removeObject(forKey: eventKey)
        saveCapital()
    }
    
    // MARK: - Contribution Tracking
    
    /// Record a completed shift
    func recordShiftCompleted(points: Int = 0) {
        myCapital.recordShiftCompleted(points: points)
        
        // Update current event if active
        if var event = currentEvent,
           let index = myCapital.eventHistory.firstIndex(where: { $0.id == event.id }) {
            var updatedEvent = myCapital.eventHistory[index]
            // Note: EventParticipation is immutable, would need to make it mutable
            // For now, just track in myCapital
            myCapital.eventHistory[index] = updatedEvent
        }
        
        saveCapital()
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: .socialCapitalUpdated, object: nil)
    }
    
    /// Record a no-show
    func recordNoShow() {
        myCapital.recordNoShow()
        saveCapital()
        NotificationCenter.default.post(name: .socialCapitalUpdated, object: nil)
    }
    
    /// Update display name
    func updateDisplayName(_ name: String) {
        myCapital.displayName = name
        saveCapital()
    }
    
    // MARK: - Trusted Network
    
    /// Add a member to the trusted network
    func addToNetwork(_ capital: SocialCapital) {
        // Don't add duplicates
        guard !trustedNetwork.members.contains(where: { $0.memberID == capital.memberID }) else { return }
        trustedNetwork.members.append(capital)
        trustedNetwork.lastUpdated = Date()
        saveNetwork()
    }
    
    /// Remove a member from the trusted network
    func removeFromNetwork(memberID: String) {
        trustedNetwork.members.removeAll { $0.memberID == memberID }
        trustedNetwork.lastUpdated = Date()
        saveNetwork()
    }
    
    /// Update a member's capital in the network
    func updateNetworkMember(_ capital: SocialCapital) {
        if let index = trustedNetwork.members.firstIndex(where: { $0.memberID == capital.memberID }) {
            trustedNetwork.members[index] = capital
            trustedNetwork.lastUpdated = Date()
            saveNetwork()
        }
    }
    
    // MARK: - Queries
    
    /// Get members at a specific trust level
    func members(atLevel level: SocialCapital.TrustLevel) -> [SocialCapital] {
        trustedNetwork.members(atLevel: level)
    }
    
    /// Check if a member is in the trusted network
    func isTrusted(memberID: String) -> Bool {
        trustedNetwork.trustedMembers.contains { $0.memberID == memberID }
    }
    
    /// Get a member's capital from the network
    func getCapital(for memberID: String) -> SocialCapital? {
        trustedNetwork.members.first { $0.memberID == memberID }
    }
    
    // MARK: - Persistence
    
    private func saveCapital() {
        if let encoded = try? JSONEncoder().encode(myCapital) {
            userDefaults.set(encoded, forKey: capitalKey)
        }
    }
    
    private func loadTrustedNetwork() {
        if let data = userDefaults.data(forKey: networkKey),
           let network = try? JSONDecoder().decode(TrustedNetwork.self, from: data) {
            trustedNetwork = network
        }
    }
    
    private func saveNetwork() {
        if let encoded = try? JSONEncoder().encode(trustedNetwork) {
            userDefaults.set(encoded, forKey: networkKey)
        }
    }
    
    private func loadCurrentEvent() {
        if let data = userDefaults.data(forKey: eventKey),
           let event = try? JSONDecoder().decode(SocialCapital.EventParticipation.self, from: data) {
            currentEvent = event
        }
    }
    
    private func saveCurrentEvent() {
        if let event = currentEvent,
           let encoded = try? JSONEncoder().encode(event) {
            userDefaults.set(encoded, forKey: eventKey)
        }
    }
    
    // MARK: - Export/Import (for portable reputation)
    
    /// Export social capital as JSON data
    func exportCapital() -> Data? {
        try? JSONEncoder().encode(myCapital)
    }
    
    /// Import social capital from another source (e.g., another camp's verification)
    func importVerifiedCapital(_ data: Data) -> SocialCapital? {
        guard let capital = try? JSONDecoder().decode(SocialCapital.self, from: data) else {
            return nil
        }
        // Add to network as a verified member
        addToNetwork(capital)
        return capital
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let socialCapitalUpdated = Notification.Name("socialCapitalUpdated")
}

// MARK: - Preview Helper
extension SocialCapitalManager {
    static var preview: SocialCapitalManager {
        let manager = SocialCapitalManager()
        manager.myCapital.totalShiftsCompleted = 12
        manager.myCapital.totalEventsParticipated = 2
        manager.myCapital.totalPointsEarned = 450
        return manager
    }
}
