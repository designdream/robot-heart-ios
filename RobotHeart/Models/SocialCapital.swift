import Foundation

// MARK: - Social Capital Model
/// Represents a person's accumulated trust and reliability across events.
/// This is the core of the "offline social network of reliable people" concept.
///
/// Social capital persists year-round and carries across:
/// - Burning Man events
/// - Off-season camping trips
/// - Regional burns
/// - Other community events
///
/// ## Philosophy
/// Unlike competitive points that reset, social capital represents genuine trust
/// built through consistent participation. It's not about winning - it's about
/// being someone others can count on.
struct SocialCapital: Codable, Identifiable {
    let id: UUID
    var memberID: String
    var displayName: String
    
    // MARK: - Lifetime Stats
    var totalShiftsCompleted: Int = 0
    var totalNoShows: Int = 0
    var totalEventsParticipated: Int = 0
    var totalPointsEarned: Int = 0
    
    // MARK: - Trust Metrics
    var reliabilityScore: Double {
        let total = totalShiftsCompleted + totalNoShows
        guard total > 0 else { return 1.0 }
        return Double(totalShiftsCompleted) / Double(total)
    }
    
    var trustLevel: TrustLevel {
        // Need minimum participation to earn trust
        guard totalShiftsCompleted >= 3 else { return .new }
        
        switch (reliabilityScore, totalShiftsCompleted) {
        case (0.95..., 20...): return .legendary
        case (0.90..., 10...): return .superstar
        case (0.80..., 5...): return .reliable
        case (0.70..., 3...): return .contributing
        case (0.50..., _): return .improving
        default: return .new
        }
    }
    
    // MARK: - Event History
    var eventHistory: [EventParticipation] = []
    
    // MARK: - Timestamps
    var firstEventDate: Date?
    var lastActiveDate: Date?
    var createdAt: Date = Date()
    
    // MARK: - Trust Level Enum
    enum TrustLevel: String, Codable, CaseIterable {
        case new = "New"
        case improving = "Improving"
        case contributing = "Contributing"
        case reliable = "Reliable"
        case superstar = "Superstar"
        case legendary = "Legendary"
        
        var icon: String {
            switch self {
            case .new: return "person.badge.plus"
            case .improving: return "arrow.up.circle"
            case .contributing: return "hands.clap"
            case .reliable: return "checkmark.seal"
            case .superstar: return "star.fill"
            case .legendary: return "crown.fill"
            }
        }
        
        var description: String {
            switch self {
            case .new: return "Just getting started"
            case .improving: return "Building trust"
            case .contributing: return "Active participant"
            case .reliable: return "Consistently shows up"
            case .superstar: return "Goes above and beyond"
            case .legendary: return "Pillar of the community"
            }
        }
        
        var minShifts: Int {
            switch self {
            case .new: return 0
            case .improving: return 1
            case .contributing: return 3
            case .reliable: return 5
            case .superstar: return 10
            case .legendary: return 20
            }
        }
    }
    
    // MARK: - Event Participation Record
    struct EventParticipation: Codable, Identifiable {
        let id: UUID
        let eventName: String
        let eventType: EventType
        let year: Int
        let shiftsCompleted: Int
        let noShows: Int
        let pointsEarned: Int
        let startDate: Date
        let endDate: Date?
        
        enum EventType: String, Codable {
            case burningMan = "Burning Man"
            case regionalBurn = "Regional Burn"
            case offSeason = "Off-Season Event"
            case campTrip = "Camp Trip"
            case other = "Other"
        }
        
        init(eventName: String, eventType: EventType, year: Int) {
            self.id = UUID()
            self.eventName = eventName
            self.eventType = eventType
            self.year = year
            self.shiftsCompleted = 0
            self.noShows = 0
            self.pointsEarned = 0
            self.startDate = Date()
            self.endDate = nil
        }
    }
    
    // MARK: - Initialization
    init(memberID: String, displayName: String) {
        self.id = UUID()
        self.memberID = memberID
        self.displayName = displayName
    }
    
    // MARK: - Methods
    mutating func recordShiftCompleted(points: Int = 0) {
        totalShiftsCompleted += 1
        totalPointsEarned += points
        lastActiveDate = Date()
    }
    
    mutating func recordNoShow() {
        totalNoShows += 1
        lastActiveDate = Date()
    }
    
    mutating func startEvent(_ event: EventParticipation) {
        if firstEventDate == nil {
            firstEventDate = Date()
        }
        totalEventsParticipated += 1
        eventHistory.append(event)
        lastActiveDate = Date()
    }
    
    // MARK: - Computed Properties
    var yearsActive: Int {
        guard let first = firstEventDate else { return 0 }
        return Calendar.current.dateComponents([.year], from: first, to: Date()).year ?? 0
    }
    
    var isVeteran: Bool {
        yearsActive >= 2 && totalEventsParticipated >= 3
    }
    
    var summaryText: String {
        if totalShiftsCompleted == 0 {
            return "No shifts yet"
        }
        return "\(totalShiftsCompleted) shifts across \(totalEventsParticipated) event\(totalEventsParticipated == 1 ? "" : "s")"
    }
}

// MARK: - Trusted Network
/// A collection of people with proven reliability.
/// This is the "offline social network" - people you can count on.
struct TrustedNetwork: Codable {
    var members: [SocialCapital] = []
    var lastUpdated: Date = Date()
    
    // Filter by trust level
    func members(atLevel level: SocialCapital.TrustLevel) -> [SocialCapital] {
        members.filter { $0.trustLevel == level }
    }
    
    // Get all trusted members (Contributing and above)
    var trustedMembers: [SocialCapital] {
        members.filter { member in
            switch member.trustLevel {
            case .contributing, .reliable, .superstar, .legendary:
                return true
            default:
                return false
            }
        }
    }
    
    // Get superstars and above
    var superstars: [SocialCapital] {
        members.filter { member in
            switch member.trustLevel {
            case .superstar, .legendary:
                return true
            default:
                return false
            }
        }
    }
    
    // Network stats
    var totalMembers: Int { members.count }
    var totalTrusted: Int { trustedMembers.count }
    var averageReliability: Double {
        guard !members.isEmpty else { return 0 }
        return members.reduce(0) { $0 + $1.reliabilityScore } / Double(members.count)
    }
}
