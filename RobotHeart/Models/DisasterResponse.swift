import Foundation
import SwiftUI

// MARK: - Disaster Response Models
/// Models for scaling Social Capital to disaster-level coordination.
/// Designed to work offline, at scale, with decentralized leadership.

// MARK: - Disaster Role
/// Roles automatically assigned based on Social Capital trust level.
/// Higher trust = more responsibility and capability.

enum DisasterRole: Int, Codable, Comparable, CaseIterable {
    case citizen = 0        // Everyone starts here
    case blockCaptain = 1   // Reliable+ with 5+ contributions
    case cellLead = 2       // Superstar+ with 10+ contributions
    case zoneCommander = 3  // Legendary with 20+ contributions
    case regionCoordinator = 4  // Legendary + verified training
    
    var title: String {
        switch self {
        case .citizen: return "Citizen"
        case .blockCaptain: return "Block Captain"
        case .cellLead: return "Cell Lead"
        case .zoneCommander: return "Zone Commander"
        case .regionCoordinator: return "Region Coordinator"
        }
    }
    
    var icon: String {
        switch self {
        case .citizen: return "person.fill"
        case .blockCaptain: return "person.badge.shield.checkmark.fill"
        case .cellLead: return "person.2.badge.gearshape.fill"
        case .zoneCommander: return "flag.fill"
        case .regionCoordinator: return "building.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .citizen: return Theme.Colors.robotCream
        case .blockCaptain: return Theme.Colors.turquoise
        case .cellLead: return Theme.Colors.goldenYellow
        case .zoneCommander: return Theme.Colors.sunsetOrange
        case .regionCoordinator: return Theme.Colors.ledMagenta
        }
    }
    
    var responsibilities: [String] {
        switch self {
        case .citizen:
            return ["Report needs", "Receive resources", "Relay messages"]
        case .blockCaptain:
            return ["Coordinate ~100 people", "Verify needs", "Distribute resources", "Report to Cell Lead"]
        case .cellLead:
            return ["Coordinate ~1,000 people", "Allocate resources", "Dispatch teams", "Report to Zone Commander"]
        case .zoneCommander:
            return ["Coordinate ~10,000 people", "Declare emergencies", "Cross-cell coordination", "Report to Region"]
        case .regionCoordinator:
            return ["Coordinate ~100,000+ people", "Cross-zone coordination", "External liaison", "Strategic decisions"]
        }
    }
    
    /// Assign role based on Social Capital
    static func assign(for capital: SocialCapital, hasTraining: Bool = false) -> DisasterRole {
        switch capital.trustLevel {
        case .legendary where hasTraining && capital.totalShiftsCompleted >= 25:
            return .regionCoordinator
        case .legendary where capital.totalShiftsCompleted >= 20:
            return .zoneCommander
        case .superstar where capital.totalShiftsCompleted >= 10:
            return .cellLead
        case .reliable where capital.totalShiftsCompleted >= 5:
            return .blockCaptain
        default:
            return .citizen
        }
    }
    
    static func < (lhs: DisasterRole, rhs: DisasterRole) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Disaster Capability
/// What actions each role can perform during a disaster.

enum DisasterCapability: String, Codable, CaseIterable {
    // Basic (everyone)
    case reportNeed = "Report Need"
    case receiveResources = "Receive Resources"
    case viewLocalInfo = "View Local Info"
    case relayMessages = "Relay Messages"
    
    // Block Captain+
    case verifyNeeds = "Verify Needs"
    case distributeResources = "Distribute Resources"
    case coordinateBlock = "Coordinate Block"
    case requestResources = "Request Resources"
    
    // Cell Lead+
    case coordinateCell = "Coordinate Cell"
    case allocateResources = "Allocate Resources"
    case dispatchTeams = "Dispatch Teams"
    
    // Zone Commander+
    case coordinateZone = "Coordinate Zone"
    case declareEmergency = "Declare Emergency"
    case overrideAllocation = "Override Allocation"
    
    // Region Coordinator
    case crossZoneCoordination = "Cross-Zone Coordination"
    case externalLiaison = "External Liaison"
    
    var icon: String {
        switch self {
        case .reportNeed: return "exclamationmark.bubble.fill"
        case .receiveResources: return "shippingbox.fill"
        case .viewLocalInfo: return "info.circle.fill"
        case .relayMessages: return "arrow.triangle.2.circlepath"
        case .verifyNeeds: return "checkmark.seal.fill"
        case .distributeResources: return "arrow.down.to.line.circle.fill"
        case .coordinateBlock: return "person.3.fill"
        case .requestResources: return "arrow.up.circle.fill"
        case .coordinateCell: return "person.3.sequence.fill"
        case .allocateResources: return "chart.pie.fill"
        case .dispatchTeams: return "figure.walk.motion"
        case .coordinateZone: return "map.fill"
        case .declareEmergency: return "bell.badge.fill"
        case .overrideAllocation: return "exclamationmark.shield.fill"
        case .crossZoneCoordination: return "globe"
        case .externalLiaison: return "antenna.radiowaves.left.and.right"
        }
    }
    
    /// Get capabilities for a role
    static func capabilities(for role: DisasterRole) -> Set<DisasterCapability> {
        switch role {
        case .citizen:
            return [.reportNeed, .receiveResources, .viewLocalInfo, .relayMessages]
            
        case .blockCaptain:
            return [.reportNeed, .receiveResources, .viewLocalInfo, .relayMessages,
                    .verifyNeeds, .distributeResources, .coordinateBlock, .requestResources]
            
        case .cellLead:
            return [.reportNeed, .receiveResources, .viewLocalInfo, .relayMessages,
                    .verifyNeeds, .distributeResources, .coordinateBlock, .requestResources,
                    .coordinateCell, .allocateResources, .dispatchTeams]
            
        case .zoneCommander:
            return Set(DisasterCapability.allCases).subtracting([.crossZoneCoordination, .externalLiaison])
            
        case .regionCoordinator:
            return Set(DisasterCapability.allCases)
        }
    }
}

// MARK: - Resource Type

enum ResourceType: String, Codable, CaseIterable, Identifiable {
    case water = "Water"
    case food = "Food"
    case medical = "Medical"
    case shelter = "Shelter"
    case power = "Power"
    case transportation = "Transportation"
    case communication = "Communication"
    case clothing = "Clothing"
    case sanitation = "Sanitation"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .food: return "fork.knife"
        case .medical: return "cross.case.fill"
        case .shelter: return "house.fill"
        case .power: return "bolt.fill"
        case .transportation: return "car.fill"
        case .communication: return "antenna.radiowaves.left.and.right"
        case .clothing: return "tshirt.fill"
        case .sanitation: return "toilet.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .water: return .blue
        case .food: return .orange
        case .medical: return .red
        case .shelter: return .brown
        case .power: return .yellow
        case .transportation: return .purple
        case .communication: return .cyan
        case .clothing: return .pink
        case .sanitation: return .gray
        }
    }
    
    var unit: String {
        switch self {
        case .water: return "liters"
        case .food: return "meals"
        case .medical: return "kits"
        case .shelter: return "spaces"
        case .power: return "charges"
        case .transportation: return "seats"
        case .communication: return "devices"
        case .clothing: return "sets"
        case .sanitation: return "supplies"
        }
    }
}

// MARK: - Need Level

enum NeedLevel: Int, Codable, Comparable, CaseIterable {
    case critical = 4  // Will die without
    case urgent = 3    // Serious harm without
    case moderate = 2  // Significant hardship
    case low = 1       // Inconvenience
    
    var label: String {
        switch self {
        case .critical: return "Critical"
        case .urgent: return "Urgent"
        case .moderate: return "Moderate"
        case .low: return "Low"
        }
    }
    
    var color: Color {
        switch self {
        case .critical: return Theme.Colors.emergency
        case .urgent: return Theme.Colors.warning
        case .moderate: return Theme.Colors.goldenYellow
        case .low: return Theme.Colors.robotCream
        }
    }
    
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.3"
        case .urgent: return "exclamationmark.2"
        case .moderate: return "exclamationmark"
        case .low: return "minus"
        }
    }
    
    var priorityScore: Double {
        switch self {
        case .critical: return 100
        case .urgent: return 70
        case .moderate: return 40
        case .low: return 10
        }
    }
    
    static func < (lhs: NeedLevel, rhs: NeedLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Resource Need

struct ResourceNeed: Identifiable, Codable {
    let id: UUID
    let memberID: String
    let memberName: String
    let resourceType: ResourceType
    let needLevel: NeedLevel
    let quantity: Int
    let description: String?
    let location: String?
    let createdAt: Date
    var verifiedBy: String?
    var verifiedAt: Date?
    var fulfilledAt: Date?
    var fulfilledBy: String?
    
    var isVerified: Bool { verifiedBy != nil }
    var isFulfilled: Bool { fulfilledAt != nil }
    var isPending: Bool { !isFulfilled }
    
    var hoursWaiting: Double {
        Date().timeIntervalSince(createdAt) / 3600
    }
    
    init(
        memberID: String,
        memberName: String,
        resourceType: ResourceType,
        needLevel: NeedLevel,
        quantity: Int = 1,
        description: String? = nil,
        location: String? = nil
    ) {
        self.id = UUID()
        self.memberID = memberID
        self.memberName = memberName
        self.resourceType = resourceType
        self.needLevel = needLevel
        self.quantity = quantity
        self.description = description
        self.location = location
        self.createdAt = Date()
    }
}

// MARK: - Resource Allocation

struct ResourceAllocation {
    
    /// Calculate priority score for resource allocation
    /// Higher score = higher priority for receiving resources
    static func priorityScore(
        for need: ResourceNeed,
        capital: SocialCapital,
        isVulnerable: Bool = false,
        contributedRecently: Bool = false
    ) -> Double {
        var score = need.needLevel.priorityScore
        
        // Vulnerability bonus (children, elderly, disabled, pregnant)
        if isVulnerable {
            score += 30
        }
        
        // Trust level (tie-breaker, not primary factor)
        switch capital.trustLevel {
        case .legendary: score += 5
        case .superstar: score += 4
        case .reliable: score += 3
        case .contributing: score += 2
        case .improving: score += 1
        case .new: score += 0
        }
        
        // Recent contribution bonus
        if contributedRecently {
            score += 10
        }
        
        // Time waiting bonus (prevents starvation of queue)
        score += min(20, need.hoursWaiting * 2)
        
        // Verification bonus
        if need.isVerified {
            score += 5
        }
        
        return score
    }
}

// MARK: - Disaster Status

enum DisasterStatus: String, Codable, CaseIterable {
    case normal = "Normal"
    case alert = "Alert"
    case emergency = "Emergency"
    case critical = "Critical"
    case recovery = "Recovery"
    
    var color: Color {
        switch self {
        case .normal: return Theme.Colors.connected
        case .alert: return Theme.Colors.goldenYellow
        case .emergency: return Theme.Colors.warning
        case .critical: return Theme.Colors.emergency
        case .recovery: return Theme.Colors.turquoise
        }
    }
    
    var icon: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .emergency: return "exclamationmark.octagon.fill"
        case .critical: return "xmark.octagon.fill"
        case .recovery: return "arrow.up.heart.fill"
        }
    }
}

// MARK: - Zone Structure

struct DisasterZone: Identifiable, Codable {
    let id: UUID
    var name: String
    var status: DisasterStatus
    var commanderID: String?
    var commanderName: String?
    var population: Int
    var cells: [DisasterCell]
    var resources: [ResourceType: Int]
    var needs: [ResourceType: Int]
    var lastUpdated: Date
    
    var totalNeeds: Int {
        needs.values.reduce(0, +)
    }
    
    var totalResources: Int {
        resources.values.reduce(0, +)
    }
    
    var resourceCoverage: Double {
        guard totalNeeds > 0 else { return 1.0 }
        return min(1.0, Double(totalResources) / Double(totalNeeds))
    }
}

struct DisasterCell: Identifiable, Codable {
    let id: UUID
    var name: String
    var leadID: String?
    var leadName: String?
    var blocks: [DisasterBlock]
    var population: Int
    var lastHeartbeat: Date
    
    var isOnline: Bool {
        Date().timeIntervalSince(lastHeartbeat) < 3600 // 1 hour
    }
}

struct DisasterBlock: Identifiable, Codable {
    let id: UUID
    var captainID: String?
    var captainName: String?
    var memberCount: Int
    var location: String?
    var status: DisasterStatus
    var lastHeartbeat: Date
    
    var isOnline: Bool {
        Date().timeIntervalSince(lastHeartbeat) < 1800 // 30 min
    }
}

// MARK: - Compact Disaster Message
/// Optimized for low-bandwidth mesh transmission

struct DisasterMessage: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: MessageType
    let priority: Int  // 0-255
    let ttl: Int       // Hops remaining
    let senderID: String
    let senderName: String
    let targetZone: String?
    let content: String
    let location: String?
    
    enum MessageType: String, Codable {
        case emergency = "SOS"
        case resourceRequest = "NEED"
        case resourceOffer = "HAVE"
        case status = "STATUS"
        case coordination = "COORD"
        case broadcast = "BCAST"
        case ack = "ACK"
        case heartbeat = "PING"
    }
    
    init(
        type: MessageType,
        priority: Int = 50,
        ttl: Int = 10,
        senderID: String,
        senderName: String,
        targetZone: String? = nil,
        content: String,
        location: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.priority = priority
        self.ttl = ttl
        self.senderID = senderID
        self.senderName = senderName
        self.targetZone = targetZone
        self.content = content
        self.location = location
    }
    
    /// Encode to compact format for transmission
    func toCompact() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    /// Decode from compact format
    static func fromCompact(_ data: Data) -> DisasterMessage? {
        try? JSONDecoder().decode(DisasterMessage.self, from: data)
    }
}

// MARK: - Rapid Onboarding

struct RapidOnboarding {
    
    /// Onboard a new user during disaster with provisional trust
    static func onboard(
        memberID: String,
        displayName: String,
        vouchedBy: SocialCapital?,
        isEmergency: Bool
    ) -> SocialCapital {
        var capital = SocialCapital(memberID: memberID, displayName: displayName)
        
        // Grant provisional trust based on voucher
        if let voucher = vouchedBy {
            switch voucher.trustLevel {
            case .legendary, .superstar:
                // High-trust voucher grants Contributing level for 72 hours
                capital.totalShiftsCompleted = 3  // Provisional
            case .reliable:
                // Medium-trust voucher grants Improving level for 48 hours
                capital.totalShiftsCompleted = 1  // Provisional
            default:
                break
            }
        }
        
        return capital
    }
    
    /// Time to onboard (target: < 3 minutes)
    static let targetOnboardingTime: TimeInterval = 180
}

// MARK: - Extensions to SocialCapital for Disaster

extension SocialCapital {
    
    /// Get disaster role based on trust level
    var disasterRole: DisasterRole {
        DisasterRole.assign(for: self)
    }
    
    /// Get capabilities for disaster response
    var disasterCapabilities: Set<DisasterCapability> {
        DisasterCapability.capabilities(for: disasterRole)
    }
    
    /// Check if member can perform a capability
    func can(_ capability: DisasterCapability) -> Bool {
        disasterCapabilities.contains(capability)
    }
}
