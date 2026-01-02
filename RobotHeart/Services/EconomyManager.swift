import Foundation
import Combine

class EconomyManager: ObservableObject {
    // MARK: - Published Properties
    @Published var myStanding: ParticipantStanding
    @Published var availableShifts: [AnonymousShift] = []
    @Published var myClaims: [ShiftClaim] = []
    @Published var activePenalties: [Penalty] = []
    @Published var leaderboard: [LeaderboardEntry] = [] // Anonymous rankings
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let standingKey = "participantStanding"
    private let claimsKey = "shiftClaims"
    private let penaltiesKey = "penalties"
    private let currentUserID = "!local"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Load or create standing
        if let data = userDefaults.data(forKey: standingKey),
           let standing = try? JSONDecoder().decode(ParticipantStanding.self, from: data) {
            myStanding = standing
        } else {
            myStanding = ParticipantStanding(id: currentUserID)
        }
        
        loadClaims()
        loadPenalties()
        loadAvailableShifts()
        
        // Check for expired penalties
        cleanupExpiredPenalties()
    }
    
    // MARK: - Shift Discovery (Anonymous)
    func refreshAvailableShifts() {
        // In production, this would fetch from mesh network
        // For now, generate mock anonymous shifts
        availableShifts = generateMockAnonymousShifts()
    }
    
    // MARK: - Claim Shift
    func claimShift(_ shift: AnonymousShift) -> Bool {
        guard shift.spotsRemaining > 0 else { return false }
        
        let claim = ShiftClaim(
            id: UUID(),
            shiftID: shift.id,
            claimedBy: currentUserID,
            claimedAt: Date(),
            status: .claimed,
            pointsAwarded: shift.totalPoints
        )
        
        myClaims.append(claim)
        saveClaims()
        
        // Broadcast claim (identity revealed to shift creator only)
        NotificationCenter.default.post(
            name: .shiftClaimed,
            object: claim
        )
        
        return true
    }
    
    // MARK: - Complete Shift
    func markShiftComplete(_ claimID: UUID) {
        guard let index = myClaims.firstIndex(where: { $0.id == claimID }) else { return }
        
        var claim = myClaims[index]
        claim.status = .completed
        claim.completedAt = Date()
        myClaims[index] = claim
        saveClaims()
        
        // Request verification
        NotificationCenter.default.post(
            name: .shiftCompletionRequested,
            object: claim
        )
    }
    
    // MARK: - Verify Shift (Admin/Lead)
    func verifyShiftCompletion(_ claimID: UUID, approved: Bool) {
        guard let index = myClaims.firstIndex(where: { $0.id == claimID }) else { return }
        
        var claim = myClaims[index]
        
        if approved {
            claim.status = .verified
            claim.verifiedBy = currentUserID
            
            // Award points
            myStanding.pointsEarned += claim.pointsAwarded
            myStanding.shiftsCompleted += 1
        } else {
            claim.status = .noShow
            
            // Apply penalty
            applyPenalty(reason: .noShow, shiftPoints: claim.pointsAwarded)
        }
        
        myClaims[index] = claim
        myStanding.lastUpdated = Date()
        
        saveClaims()
        saveStanding()
    }
    
    // MARK: - No-Show Detection
    func reportNoShow(_ claimID: UUID) {
        guard let index = myClaims.firstIndex(where: { $0.id == claimID }) else { return }
        
        var claim = myClaims[index]
        claim.status = .noShow
        myClaims[index] = claim
        
        myStanding.shiftsNoShow += 1
        
        applyPenalty(reason: .noShow, shiftPoints: claim.pointsAwarded)
        
        saveClaims()
        saveStanding()
    }
    
    // MARK: - Penalty System
    func applyPenalty(reason: Penalty.PenaltyReason, shiftPoints: Int) {
        let (duration, pointDeduction, privileges) = PointCalculator.calculatePenalty(
            reason: reason,
            tier: myStanding.currentTier,
            shiftPoints: shiftPoints
        )
        
        let penalty = Penalty(
            id: UUID(),
            memberID: currentUserID,
            reason: reason,
            privilegesAffected: privileges,
            startTime: Date(),
            endTime: Date().addingTimeInterval(duration),
            pointDeduction: pointDeduction,
            acknowledged: false
        )
        
        activePenalties.append(penalty)
        
        // Deduct points
        myStanding.pointsEarned = max(0, myStanding.pointsEarned - pointDeduction)
        
        // Suspend privileges
        for privilege in privileges {
            if !myStanding.suspendedPrivileges.contains(privilege) {
                myStanding.suspendedPrivileges.append(privilege)
            }
        }
        
        myStanding.suspensionEnds = penalty.endTime
        
        savePenalties()
        saveStanding()
        
        // Notify
        NotificationCenter.default.post(
            name: .penaltyApplied,
            object: penalty
        )
    }
    
    func acknowledgePenalty(_ penaltyID: UUID) {
        guard let index = activePenalties.firstIndex(where: { $0.id == penaltyID }) else { return }
        activePenalties[index].acknowledged = true
        savePenalties()
    }
    
    private func cleanupExpiredPenalties() {
        let now = Date()
        
        // Remove expired penalties
        activePenalties.removeAll { $0.endTime < now }
        
        // Restore privileges if no active penalties
        if activePenalties.isEmpty {
            myStanding.suspendedPrivileges = []
            myStanding.suspensionEnds = nil
        } else {
            // Update suspension end to latest penalty
            myStanding.suspensionEnds = activePenalties.map { $0.endTime }.max()
        }
        
        savePenalties()
        saveStanding()
    }
    
    // MARK: - Privilege Check
    func hasPrivilege(_ privilege: ShiftEconomy.Privilege) -> Bool {
        myStanding.activePrivileges.contains(privilege)
    }
    
    func privilegeStatus(_ privilege: ShiftEconomy.Privilege) -> PrivilegeStatus {
        if myStanding.suspendedPrivileges.contains(privilege) {
            return .suspended(until: myStanding.suspensionEnds)
        } else if myStanding.currentTier.privileges.contains(privilege) {
            return .active
        } else {
            return .notAvailable
        }
    }
    
    enum PrivilegeStatus {
        case active
        case suspended(until: Date?)
        case notAvailable
    }
    
    // MARK: - Leaderboard (Named for Accountability)
    struct LeaderboardEntry: Identifiable {
        let id = UUID()
        let memberID: String
        let memberName: String      // Playa name - accountability requires names
        let rank: Int
        let points: Int
        let shiftsCompleted: Int
        let shiftsNoShow: Int       // Show no-shows for accountability
        let reliability: Double
        let isMe: Bool
        
        var reliabilityStatus: ReliabilityStatus {
            if shiftsNoShow == 0 && reliability >= 0.95 { return .superstar }
            if reliability >= 0.9 { return .reliable }
            if reliability >= 0.75 { return .needsImprovement }
            return .unreliable
        }
        
        enum ReliabilityStatus: String {
            case superstar = "⭐ Superstar"
            case reliable = "✓ Reliable"
            case needsImprovement = "⚠️ Needs Improvement"
            case unreliable = "❌ Unreliable"
            
            var color: String {
                switch self {
                case .superstar: return "goldenYellow"
                case .reliable: return "connected"
                case .needsImprovement: return "warning"
                case .unreliable: return "disconnected"
                }
            }
        }
    }
    
    func refreshLeaderboard() {
        // In production, aggregate from mesh network
        // ACCOUNTABILITY: Show names and no-show counts - no anonymity for performance
        leaderboard = [
            LeaderboardEntry(memberID: "1", memberName: "Sparkle", rank: 1, points: 95, shiftsCompleted: 8, shiftsNoShow: 0, reliability: 1.0, isMe: false),
            LeaderboardEntry(memberID: "2", memberName: "Dusty", rank: 2, points: 82, shiftsCompleted: 7, shiftsNoShow: 0, reliability: 1.0, isMe: false),
            LeaderboardEntry(memberID: "3", memberName: "Blaze", rank: 3, points: 78, shiftsCompleted: 6, shiftsNoShow: 1, reliability: 0.86, isMe: false),
            LeaderboardEntry(memberID: currentUserID, memberName: "You", rank: 4, points: myStanding.pointsEarned, shiftsCompleted: myStanding.shiftsCompleted, shiftsNoShow: myStanding.shiftsNoShow, reliability: myStanding.reliabilityScore, isMe: true),
            LeaderboardEntry(memberID: "5", memberName: "Phoenix", rank: 5, points: 65, shiftsCompleted: 5, shiftsNoShow: 0, reliability: 1.0, isMe: false),
        ].sorted { $0.points > $1.points }
    }
    
    // MARK: - Persistence
    private func saveStanding() {
        if let encoded = try? JSONEncoder().encode(myStanding) {
            userDefaults.set(encoded, forKey: standingKey)
        }
    }
    
    private func saveClaims() {
        if let encoded = try? JSONEncoder().encode(myClaims) {
            userDefaults.set(encoded, forKey: claimsKey)
        }
    }
    
    private func loadClaims() {
        if let data = userDefaults.data(forKey: claimsKey),
           let decoded = try? JSONDecoder().decode([ShiftClaim].self, from: data) {
            myClaims = decoded
        }
    }
    
    private func savePenalties() {
        if let encoded = try? JSONEncoder().encode(activePenalties) {
            userDefaults.set(encoded, forKey: penaltiesKey)
        }
    }
    
    private func loadPenalties() {
        if let data = userDefaults.data(forKey: penaltiesKey),
           let decoded = try? JSONDecoder().decode([Penalty].self, from: data) {
            activePenalties = decoded.filter { $0.isActive }
        }
    }
    
    private func loadAvailableShifts() {
        availableShifts = generateMockAnonymousShifts()
    }
    
    // MARK: - Mock Data
    private func generateMockAnonymousShifts() -> [AnonymousShift] {
        let now = Date()
        return [
            AnonymousShift(
                id: UUID(),
                location: Shift.ShiftLocation.bus,
                startTime: now.addingTimeInterval(3600),
                endTime: now.addingTimeInterval(7200),
                pointValue: 15,
                urgencyBonus: 5,
                requirements: nil,
                spotsAvailable: 2,
                spotsClaimed: 1
            ),
            AnonymousShift(
                id: UUID(),
                location: Shift.ShiftLocation.shadyBot,
                startTime: now.addingTimeInterval(7200),
                endTime: now.addingTimeInterval(10800),
                pointValue: 18,
                urgencyBonus: 0,
                requirements: nil,
                spotsAvailable: 3,
                spotsClaimed: 0
            ),
            AnonymousShift(
                id: UUID(),
                location: Shift.ShiftLocation.camp,
                startTime: now.addingTimeInterval(14400),
                endTime: now.addingTimeInterval(18000),
                pointValue: 12,
                urgencyBonus: 0,
                requirements: ["Ice distribution"],
                spotsAvailable: 2,
                spotsClaimed: 0
            ),
            AnonymousShift(
                id: UUID(),
                location: Shift.ShiftLocation.bus,
                startTime: now.addingTimeInterval(86400),
                endTime: now.addingTimeInterval(90000),
                pointValue: 22,
                urgencyBonus: 0,
                requirements: nil,
                spotsAvailable: 4,
                spotsClaimed: 2
            )
        ]
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let shiftClaimed = Notification.Name("shiftClaimed")
    static let shiftCompletionRequested = Notification.Name("shiftCompletionRequested")
    static let penaltyApplied = Notification.Name("penaltyApplied")
}
