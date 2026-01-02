import Foundation

// MARK: - Shift Draft System
// Sports-style draft where admins define shifts and members pick in rounds

struct ShiftDraft: Identifiable, Codable {
    let id: UUID
    var name: String // "Week 1 Draft", "Teardown Draft"
    var status: DraftStatus
    let createdBy: String
    let createdAt: Date
    var scheduledStart: Date?
    var actualStart: Date?
    var completedAt: Date?
    var currentRound: Int
    var currentPickIndex: Int
    var pickOrder: [String] // Member IDs in pick order
    var availableShifts: [DraftableShift]
    var picks: [DraftPick]
    var settings: DraftSettings
    
    enum DraftStatus: String, Codable {
        case setup = "Setup"           // Admin defining shifts
        case scheduled = "Scheduled"   // Waiting to start
        case active = "Active"         // Draft in progress
        case paused = "Paused"         // Temporarily paused
        case completed = "Completed"   // All picks made
        case cancelled = "Cancelled"
        
        var icon: String {
            switch self {
            case .setup: return "hammer.fill"
            case .scheduled: return "calendar.badge.clock"
            case .active: return "play.circle.fill"
            case .paused: return "pause.circle.fill"
            case .completed: return "checkmark.circle.fill"
            case .cancelled: return "xmark.circle.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        createdBy: String,
        scheduledStart: Date? = nil,
        settings: DraftSettings = DraftSettings()
    ) {
        self.id = id
        self.name = name
        self.status = .setup
        self.createdBy = createdBy
        self.createdAt = Date()
        self.scheduledStart = scheduledStart
        self.actualStart = nil
        self.completedAt = nil
        self.currentRound = 1
        self.currentPickIndex = 0
        self.pickOrder = []
        self.availableShifts = []
        self.picks = []
        self.settings = settings
    }
    
    // MARK: - Computed Properties
    var totalRounds: Int {
        settings.roundsPerParticipant
    }
    
    var totalPicks: Int {
        pickOrder.count * totalRounds
    }
    
    var picksMade: Int {
        picks.count
    }
    
    var currentPicker: String? {
        guard status == .active, currentPickIndex < pickOrder.count else { return nil }
        
        // Snake draft: odd rounds go reverse
        if currentRound % 2 == 0 {
            return pickOrder[pickOrder.count - 1 - currentPickIndex]
        }
        return pickOrder[currentPickIndex]
    }
    
    var remainingShifts: [DraftableShift] {
        let pickedShiftIDs = Set(picks.map { $0.shiftID })
        return availableShifts.filter { !pickedShiftIDs.contains($0.id) }
    }
    
    var isMyTurn: Bool {
        currentPicker == "!local"
    }
    
    var timePerPick: TimeInterval {
        settings.secondsPerPick
    }
    
    func shiftsPickedBy(_ memberID: String) -> [DraftableShift] {
        let memberPickIDs = picks.filter { $0.memberID == memberID }.map { $0.shiftID }
        return availableShifts.filter { memberPickIDs.contains($0.id) }
    }
    
    func pointsEarnedBy(_ memberID: String) -> Int {
        shiftsPickedBy(memberID).reduce(0) { $0 + $1.pointValue }
    }
}

// MARK: - Draft Settings
struct DraftSettings: Codable {
    var roundsPerParticipant: Int = 3      // Each person picks X shifts
    var secondsPerPick: TimeInterval = 60  // Time limit per pick
    var allowTradesAfterDraft: Bool = true
    var snakeDraft: Bool = true            // Reverse order each round
    var autoPick: Bool = true              // Auto-pick if time expires
    var minimumPointsTarget: Int = 50      // Target points per person
    var randomizeOrder: Bool = true        // Randomize initial pick order
}

// MARK: - Draftable Shift (Admin-defined)
struct DraftableShift: Identifiable, Codable, Equatable {
    let id: UUID
    let location: Shift.ShiftLocation
    let startTime: Date
    let endTime: Date
    let pointValue: Int
    let description: String?
    let requirements: [String]?
    let difficulty: Difficulty
    let createdBy: String
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        case expert = "Expert"
        
        var multiplier: Double {
            switch self {
            case .easy: return 0.8
            case .medium: return 1.0
            case .hard: return 1.3
            case .expert: return 1.6
            }
        }
        
        var color: String {
            switch self {
            case .easy: return "connected"
            case .medium: return "turquoise"
            case .hard: return "sunsetOrange"
            case .expert: return "emergency"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        location: Shift.ShiftLocation,
        startTime: Date,
        endTime: Date,
        pointValue: Int? = nil,
        description: String? = nil,
        requirements: [String]? = nil,
        difficulty: Difficulty = .medium,
        createdBy: String
    ) {
        self.id = id
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.description = description
        self.requirements = requirements
        self.difficulty = difficulty
        self.createdBy = createdBy
        
        // Auto-calculate points if not provided
        if let points = pointValue {
            self.pointValue = points
        } else {
            let hours = endTime.timeIntervalSince(startTime) / 3600
            let basePoints = Int(hours * 10)
            self.pointValue = Int(Double(basePoints) * difficulty.multiplier)
        }
    }
    
    var durationText: String {
        let hours = endTime.timeIntervalSince(startTime) / 3600
        if hours < 1 {
            return "\(Int(hours * 60))min"
        }
        return String(format: "%.1fh", hours)
    }
    
    var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: startTime)
    }
}

// MARK: - Draft Pick
struct DraftPick: Identifiable, Codable {
    let id: UUID
    let draftID: UUID
    let round: Int
    let pickNumber: Int
    let memberID: String
    let memberName: String
    let shiftID: UUID
    let timestamp: Date
    let wasAutoPick: Bool
    
    init(
        id: UUID = UUID(),
        draftID: UUID,
        round: Int,
        pickNumber: Int,
        memberID: String,
        memberName: String,
        shiftID: UUID,
        wasAutoPick: Bool = false
    ) {
        self.id = id
        self.draftID = draftID
        self.round = round
        self.pickNumber = pickNumber
        self.memberID = memberID
        self.memberName = memberName
        self.shiftID = shiftID
        self.timestamp = Date()
        self.wasAutoPick = wasAutoPick
    }
}

// MARK: - Draft Event (for live updates)
struct DraftEvent: Identifiable, Codable {
    let id: UUID
    let draftID: UUID
    let type: EventType
    let timestamp: Date
    let memberID: String?
    let message: String
    
    enum EventType: String, Codable {
        case draftStarted = "Draft Started"
        case pickMade = "Pick Made"
        case autoPick = "Auto Pick"
        case roundComplete = "Round Complete"
        case draftComplete = "Draft Complete"
        case draftPaused = "Draft Paused"
        case draftResumed = "Draft Resumed"
        case tradeProposed = "Trade Proposed"
        case tradeCompleted = "Trade Completed"
    }
}

// MARK: - Draft Participant
struct DraftParticipant: Identifiable, Codable {
    let id: String // Member ID
    var name: String
    var pickPosition: Int
    var shiftsSelected: [UUID]
    var totalPoints: Int
    var isOnline: Bool
    var lastSeen: Date
    
    init(id: String, name: String, pickPosition: Int) {
        self.id = id
        self.name = name
        self.pickPosition = pickPosition
        self.shiftsSelected = []
        self.totalPoints = 0
        self.isOnline = true
        self.lastSeen = Date()
    }
}
