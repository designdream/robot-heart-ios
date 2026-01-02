import Foundation

// MARK: - Points-Based Shift Economy

struct ShiftEconomy {
    // MARK: - Point Values
    struct PointValues {
        // Base points by location difficulty
        static let busShift: Int = 10        // High visibility, desirable
        static let shadyBotShift: Int = 12   // Slightly harder
        static let campShift: Int = 8        // General camp work
        static let buildShift: Int = 15      // Physical labor
        static let teardownShift: Int = 20   // End of event, hardest
        
        // Time multipliers
        static let nightMultiplier: Double = 1.5      // 10pm - 6am
        static let sunriseMultiplier: Double = 1.3    // 6am - 10am
        static let peakHeatMultiplier: Double = 1.4   // 12pm - 4pm
        static let lateWeekMultiplier: Double = 1.2   // Thu-Sun
        static let teardownDayMultiplier: Double = 2.0 // Final day
        
        // Dynamic pricing (unfilled shift bonus)
        static let urgentBonus: Int = 5       // < 2 hours until start
        static let criticalBonus: Int = 10    // < 30 min until start
        
        // Minimum required points per participant
        static let minimumPointsRequired: Int = 50
        static let recommendedPoints: Int = 75
    }
    
    // MARK: - Privilege Tiers
    enum PrivilegeTier: Int, Codable, CaseIterable {
        case basic = 0      // Minimal resource usage
        case standard = 1   // Normal camp member
        case enhanced = 2   // Extra amenities
        case premium = 3    // Full access + vehicle
        
        var name: String {
            switch self {
            case .basic: return "Basic"
            case .standard: return "Standard"
            case .enhanced: return "Enhanced"
            case .premium: return "Premium"
            }
        }
        
        var penaltyMultiplier: Double {
            switch self {
            case .basic: return 1.0
            case .standard: return 1.5
            case .enhanced: return 2.0
            case .premium: return 3.0
            }
        }
        
        var privileges: [Privilege] {
            switch self {
            case .basic:
                return [.campAccess, .waterBasic]
            case .standard:
                return [.campAccess, .waterBasic, .powerCharging, .mealAccess]
            case .enhanced:
                return [.campAccess, .waterBasic, .waterShower, .powerCharging, .powerCamp, .mealAccess, .artCarRides]
            case .premium:
                return Privilege.allCases
            }
        }
    }
    
    enum Privilege: String, Codable, CaseIterable {
        case campAccess = "Camp Access"
        case waterBasic = "Water (Drinking)"
        case waterShower = "Shower Access"
        case powerCharging = "Device Charging"
        case powerCamp = "Camp Power"
        case mealAccess = "Meal Access"
        case artCarRides = "Art Car Rides"
        case vehicleAccess = "Vehicle Access"
        case priorityShifts = "Priority Shift Selection"
        
        var icon: String {
            switch self {
            case .campAccess: return "house.fill"
            case .waterBasic: return "drop.fill"
            case .waterShower: return "shower.fill"
            case .powerCharging: return "battery.100.bolt"
            case .powerCamp: return "bolt.fill"
            case .mealAccess: return "fork.knife"
            case .artCarRides: return "car.fill"
            case .vehicleAccess: return "suv.side.fill"
            case .priorityShifts: return "star.fill"
            }
        }
    }
}

// MARK: - Participant Standing
struct ParticipantStanding: Codable, Identifiable {
    let id: String // Member ID
    var pointsEarned: Int
    var pointsRequired: Int
    var shiftsCompleted: Int
    var shiftsNoShow: Int
    var currentTier: ShiftEconomy.PrivilegeTier
    var suspendedPrivileges: [ShiftEconomy.Privilege]
    var suspensionEnds: Date?
    var lastUpdated: Date
    
    init(
        id: String,
        pointsEarned: Int = 0,
        pointsRequired: Int = ShiftEconomy.PointValues.minimumPointsRequired,
        shiftsCompleted: Int = 0,
        shiftsNoShow: Int = 0,
        currentTier: ShiftEconomy.PrivilegeTier = .standard,
        suspendedPrivileges: [ShiftEconomy.Privilege] = [],
        suspensionEnds: Date? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.pointsEarned = pointsEarned
        self.pointsRequired = pointsRequired
        self.shiftsCompleted = shiftsCompleted
        self.shiftsNoShow = shiftsNoShow
        self.currentTier = currentTier
        self.suspendedPrivileges = suspendedPrivileges
        self.suspensionEnds = suspensionEnds
        self.lastUpdated = lastUpdated
    }
    
    var pointsRemaining: Int {
        max(0, pointsRequired - pointsEarned)
    }
    
    var completionPercentage: Double {
        guard pointsRequired > 0 else { return 1.0 }
        return min(1.0, Double(pointsEarned) / Double(pointsRequired))
    }
    
    var isInGoodStanding: Bool {
        suspendedPrivileges.isEmpty && shiftsNoShow == 0
    }
    
    var reliabilityScore: Double {
        guard shiftsCompleted + shiftsNoShow > 0 else { return 1.0 }
        return Double(shiftsCompleted) / Double(shiftsCompleted + shiftsNoShow)
    }
    
    var activePrivileges: [ShiftEconomy.Privilege] {
        currentTier.privileges.filter { !suspendedPrivileges.contains($0) }
    }
}

// MARK: - Anonymous Shift (for discovery)
struct AnonymousShift: Identifiable, Codable {
    let id: UUID
    let location: Shift.ShiftLocation
    let startTime: Date
    let endTime: Date
    let pointValue: Int
    let urgencyBonus: Int
    let requirements: [String]? // Skills needed
    let spotsAvailable: Int
    let spotsClaimed: Int
    
    // Hidden until claimed
    // assignedBy is NOT exposed
    // other claimants are NOT exposed
    
    var totalPoints: Int {
        pointValue + urgencyBonus
    }
    
    var isUrgent: Bool {
        urgencyBonus > 0
    }
    
    var spotsRemaining: Int {
        spotsAvailable - spotsClaimed
    }
    
    var timeUntilStart: TimeInterval {
        startTime.timeIntervalSinceNow
    }
    
    var durationHours: Double {
        endTime.timeIntervalSince(startTime) / 3600
    }
}

// MARK: - Shift Claim
struct ShiftClaim: Identifiable, Codable {
    let id: UUID
    let shiftID: UUID
    let claimedBy: String
    let claimedAt: Date
    var status: ClaimStatus
    var completedAt: Date?
    var verifiedBy: String?
    var pointsAwarded: Int
    
    enum ClaimStatus: String, Codable {
        case claimed = "Claimed"
        case inProgress = "In Progress"
        case completed = "Completed"
        case verified = "Verified"
        case noShow = "No Show"
        case cancelled = "Cancelled"
    }
}

// MARK: - Penalty
struct Penalty: Identifiable, Codable {
    let id: UUID
    let memberID: String
    let reason: PenaltyReason
    let privilegesAffected: [ShiftEconomy.Privilege]
    let startTime: Date
    let endTime: Date
    let pointDeduction: Int
    var acknowledged: Bool
    
    enum PenaltyReason: String, Codable {
        case noShow = "Missed Shift"
        case lateArrival = "Late Arrival"
        case earlyDeparture = "Left Early"
        case incompleteWork = "Incomplete Work"
        case pointDeficit = "Point Deficit"
        
        var baseDuration: TimeInterval {
            switch self {
            case .noShow: return 4 * 3600        // 4 hours
            case .lateArrival: return 2 * 3600   // 2 hours
            case .earlyDeparture: return 2 * 3600
            case .incompleteWork: return 1 * 3600
            case .pointDeficit: return 8 * 3600  // 8 hours
            }
        }
    }
    
    var isActive: Bool {
        Date() < endTime
    }
    
    var remainingTime: TimeInterval {
        max(0, endTime.timeIntervalSinceNow)
    }
}

// MARK: - Point Calculator
struct PointCalculator {
    static func calculatePoints(for shift: Shift) -> Int {
        var basePoints: Int
        
        // Base points by location
        switch shift.location {
        case .bus:
            basePoints = ShiftEconomy.PointValues.busShift
        case .shadyBot:
            basePoints = ShiftEconomy.PointValues.shadyBotShift
        case .camp:
            basePoints = ShiftEconomy.PointValues.campShift
        }
        
        // Duration multiplier (per hour)
        let hours = shift.endTime.timeIntervalSince(shift.startTime) / 3600
        basePoints = Int(Double(basePoints) * hours)
        
        // Time-of-day multiplier
        let hour = Calendar.current.component(.hour, from: shift.startTime)
        var multiplier: Double = 1.0
        
        if hour >= 22 || hour < 6 {
            multiplier = ShiftEconomy.PointValues.nightMultiplier
        } else if hour >= 6 && hour < 10 {
            multiplier = ShiftEconomy.PointValues.sunriseMultiplier
        } else if hour >= 12 && hour < 16 {
            multiplier = ShiftEconomy.PointValues.peakHeatMultiplier
        }
        
        // Day-of-week multiplier
        let weekday = Calendar.current.component(.weekday, from: shift.startTime)
        if weekday >= 5 { // Thu-Sun
            multiplier *= ShiftEconomy.PointValues.lateWeekMultiplier
        }
        
        return Int(Double(basePoints) * multiplier)
    }
    
    static func calculateUrgencyBonus(for shift: Shift) -> Int {
        let timeUntil = shift.startTime.timeIntervalSinceNow
        
        if timeUntil < 30 * 60 { // < 30 min
            return ShiftEconomy.PointValues.criticalBonus
        } else if timeUntil < 2 * 3600 { // < 2 hours
            return ShiftEconomy.PointValues.urgentBonus
        }
        
        return 0
    }
    
    static func calculatePenalty(
        reason: Penalty.PenaltyReason,
        tier: ShiftEconomy.PrivilegeTier,
        shiftPoints: Int
    ) -> (duration: TimeInterval, pointDeduction: Int, privileges: [ShiftEconomy.Privilege]) {
        
        // Scale duration by privilege tier
        let baseDuration = reason.baseDuration
        let scaledDuration = baseDuration * tier.penaltyMultiplier
        
        // Point deduction scales with tier
        let pointDeduction = Int(Double(shiftPoints) * tier.penaltyMultiplier)
        
        // Privileges affected based on severity
        var affectedPrivileges: [ShiftEconomy.Privilege] = []
        
        switch reason {
        case .noShow:
            // Most severe - lose non-essential privileges
            affectedPrivileges = [.artCarRides, .priorityShifts, .vehicleAccess]
            if tier.rawValue >= ShiftEconomy.PrivilegeTier.enhanced.rawValue {
                affectedPrivileges.append(.waterShower)
            }
        case .lateArrival, .earlyDeparture:
            affectedPrivileges = [.priorityShifts]
        case .incompleteWork:
            affectedPrivileges = [.priorityShifts]
        case .pointDeficit:
            // Progressive - more deficit = more restrictions
            affectedPrivileges = [.artCarRides, .priorityShifts]
        }
        
        return (scaledDuration, pointDeduction, affectedPrivileges)
    }
}
