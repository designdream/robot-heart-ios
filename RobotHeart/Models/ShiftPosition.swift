import Foundation

// MARK: - Shift Position Types
// All the different jobs/roles within a shift

enum ShiftJobType: String, Codable, CaseIterable, Identifiable {
    // Bus positions
    case lighting = "Lighting"
    case sound = "Sound"
    case heart = "Heart"
    case frontDoor = "Front Door"
    case artistRelations = "Artist Relations"
    
    // Camp positions
    case kitchen = "Kitchen"
    case kitchenCleanup = "Kitchen Cleanup"
    case bathrooms = "Bathrooms"
    case fluffing = "Fluffing"
    case electricity = "Electricity"
    case rvPumping = "RV Pumping"
    case rvFill = "RV Fill"
    case toolShed = "Tool Shed"
    case inventoryManagement = "Inventory"
    case strike = "Strike"
    case general = "General"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .lighting: return "lightbulb.fill"
        case .sound: return "speaker.wave.3.fill"
        case .heart: return "heart.fill"
        case .frontDoor: return "door.left.hand.open"
        case .artistRelations: return "person.2.fill"
        case .kitchen: return "fork.knife"
        case .kitchenCleanup: return "sink.fill"
        case .bathrooms: return "toilet.fill"
        case .fluffing: return "sparkles"
        case .electricity: return "bolt.fill"
        case .rvPumping: return "arrow.down.to.line"
        case .rvFill: return "drop.fill"
        case .toolShed: return "wrench.and.screwdriver.fill"
        case .inventoryManagement: return "list.clipboard.fill"
        case .strike: return "hammer.fill"
        case .general: return "person.fill"
        }
    }
    
    var category: JobCategory {
        switch self {
        case .lighting, .sound, .heart, .frontDoor, .artistRelations:
            return .bus
        case .kitchen, .kitchenCleanup, .bathrooms, .fluffing:
            return .campLife
        case .electricity, .rvPumping, .rvFill, .toolShed, .inventoryManagement:
            return .infrastructure
        case .strike, .general:
            return .operations
        }
    }
    
    var difficulty: Int {
        switch self {
        case .lighting, .sound: return 3
        case .heart, .artistRelations: return 2
        case .frontDoor: return 1
        case .kitchen: return 2
        case .kitchenCleanup, .bathrooms: return 2
        case .fluffing: return 1
        case .electricity: return 3
        case .rvPumping, .rvFill: return 2
        case .toolShed, .inventoryManagement: return 1
        case .strike: return 3
        case .general: return 1
        }
    }
    
    var basePoints: Int {
        difficulty * 5
    }
    
    enum JobCategory: String, Codable, CaseIterable {
        case bus = "Bus"
        case campLife = "Camp Life"
        case infrastructure = "Infrastructure"
        case operations = "Operations"
        
        var color: String {
            switch self {
            case .bus: return "sunsetOrange"
            case .campLife: return "turquoise"
            case .infrastructure: return "goldenYellow"
            case .operations: return "dustyPink"
            }
        }
    }
}

// MARK: - Shift Slot (a position within a shift)
struct ShiftSlot: Identifiable, Codable, Equatable {
    let id: UUID
    let jobType: ShiftJobType
    var assignedTo: String?      // Member ID
    var assignedName: String?    // Member name (for display)
    var assignedAt: Date?
    var status: SlotStatus
    
    enum SlotStatus: String, Codable {
        case open = "Open"
        case claimed = "Claimed"
        case confirmed = "Confirmed"
        case completed = "Completed"
        case noShow = "No Show"
    }
    
    init(
        id: UUID = UUID(),
        jobType: ShiftJobType,
        assignedTo: String? = nil,
        assignedName: String? = nil,
        status: SlotStatus = .open
    ) {
        self.id = id
        self.jobType = jobType
        self.assignedTo = assignedTo
        self.assignedName = assignedName
        self.assignedAt = assignedTo != nil ? Date() : nil
        self.status = status
    }
    
    var isAvailable: Bool {
        status == .open && assignedTo == nil
    }
    
    var pointValue: Int {
        jobType.basePoints
    }
}

// MARK: - Enhanced Shift Block (a time block with multiple positions)
struct ShiftBlock: Identifiable, Codable {
    let id: UUID
    let location: Shift.ShiftLocation
    let startTime: Date
    let endTime: Date
    var slots: [ShiftSlot]
    var isReleased: Bool         // Admin has opened it for claiming
    var releasedAt: Date?
    var releasedBy: String?
    let createdBy: String
    let createdAt: Date
    var notes: String?
    
    init(
        id: UUID = UUID(),
        location: Shift.ShiftLocation,
        startTime: Date,
        endTime: Date,
        slots: [ShiftSlot] = [],
        isReleased: Bool = false,
        createdBy: String,
        notes: String? = nil
    ) {
        self.id = id
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.slots = slots
        self.isReleased = isReleased
        self.releasedAt = nil
        self.releasedBy = nil
        self.createdBy = createdBy
        self.createdAt = Date()
        self.notes = notes
    }
    
    // MARK: - Computed Properties
    var totalSlots: Int {
        slots.count
    }
    
    var filledSlots: Int {
        slots.filter { !$0.isAvailable }.count
    }
    
    var openSlots: Int {
        slots.filter { $0.isAvailable }.count
    }
    
    var isFull: Bool {
        openSlots == 0
    }
    
    var fillPercentage: Double {
        guard totalSlots > 0 else { return 0 }
        return Double(filledSlots) / Double(totalSlots)
    }
    
    var durationHours: Double {
        endTime.timeIntervalSince(startTime) / 3600
    }
    
    var totalPoints: Int {
        slots.reduce(0) { $0 + $1.pointValue }
    }
    
    var assignedMembers: [(name: String, job: ShiftJobType)] {
        slots.compactMap { slot in
            guard let name = slot.assignedName else { return nil }
            return (name: name, job: slot.jobType)
        }
    }
    
    // Time formatting
    var timeRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startTime)
    }
    
    var shortDayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: startTime)
    }
    
    // MARK: - Slot Management
    mutating func claimSlot(_ slotID: UUID, by memberID: String, name: String) -> Bool {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return false }
        guard slots[index].isAvailable else { return false }
        
        slots[index].assignedTo = memberID
        slots[index].assignedName = name
        slots[index].assignedAt = Date()
        slots[index].status = .claimed
        
        return true
    }
    
    mutating func releaseSlot(_ slotID: UUID) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        
        slots[index].assignedTo = nil
        slots[index].assignedName = nil
        slots[index].assignedAt = nil
        slots[index].status = .open
    }
    
    mutating func release(by adminID: String) {
        isReleased = true
        releasedAt = Date()
        releasedBy = adminID
    }
    
    // Check if member is already on this shift
    func hasMember(_ memberID: String) -> Bool {
        slots.contains { $0.assignedTo == memberID }
    }
    
    // Get slots by category
    func slots(for category: ShiftJobType.JobCategory) -> [ShiftSlot] {
        slots.filter { $0.jobType.category == category }
    }
}

// MARK: - Shift Schedule (collection of blocks for a time period)
struct ShiftSchedule: Codable {
    var blocks: [ShiftBlock]
    let eventStartDate: Date
    let eventEndDate: Date
    
    init(eventStartDate: Date, eventEndDate: Date) {
        self.blocks = []
        self.eventStartDate = eventStartDate
        self.eventEndDate = eventEndDate
    }
    
    // Get blocks for a specific day
    func blocks(for date: Date) -> [ShiftBlock] {
        let calendar = Calendar.current
        return blocks.filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    // Get all days that have shifts
    var daysWithShifts: [Date] {
        let calendar = Calendar.current
        let days = Set(blocks.map { calendar.startOfDay(for: $0.startTime) })
        return Array(days).sorted()
    }
    
    // Check if member can claim (24-hour rule)
    func canMemberClaim(_ memberID: String, block: ShiftBlock) -> (canClaim: Bool, reason: String?) {
        // Find all blocks this member is assigned to
        let memberBlocks = blocks.filter { $0.hasMember(memberID) }
        
        for existingBlock in memberBlocks {
            // Check if within 24 hours
            let timeDiff = abs(block.startTime.timeIntervalSince(existingBlock.startTime))
            if timeDiff < 24 * 3600 {
                return (false, "You already have a shift within 24 hours of this one")
            }
        }
        
        return (true, nil)
    }
}

// MARK: - Preset Shift Templates
extension ShiftBlock {
    static func busShiftTemplate(startTime: Date, endTime: Date, createdBy: String) -> ShiftBlock {
        var block = ShiftBlock(
            location: .bus,
            startTime: startTime,
            endTime: endTime,
            createdBy: createdBy
        )
        
        // Standard bus positions
        block.slots = [
            ShiftSlot(jobType: .lighting),
            ShiftSlot(jobType: .lighting),
            ShiftSlot(jobType: .sound),
            ShiftSlot(jobType: .sound),
            ShiftSlot(jobType: .heart),
            ShiftSlot(jobType: .frontDoor),
            ShiftSlot(jobType: .frontDoor),
            ShiftSlot(jobType: .artistRelations)
        ]
        
        return block
    }
    
    static func campShiftTemplate(startTime: Date, endTime: Date, createdBy: String) -> ShiftBlock {
        var block = ShiftBlock(
            location: .camp,
            startTime: startTime,
            endTime: endTime,
            createdBy: createdBy
        )
        
        block.slots = [
            ShiftSlot(jobType: .kitchen),
            ShiftSlot(jobType: .kitchen),
            ShiftSlot(jobType: .kitchenCleanup),
            ShiftSlot(jobType: .bathrooms),
            ShiftSlot(jobType: .fluffing),
            ShiftSlot(jobType: .general)
        ]
        
        return block
    }
    
    static func infrastructureShiftTemplate(startTime: Date, endTime: Date, createdBy: String) -> ShiftBlock {
        var block = ShiftBlock(
            location: .camp,
            startTime: startTime,
            endTime: endTime,
            createdBy: createdBy
        )
        
        block.slots = [
            ShiftSlot(jobType: .electricity),
            ShiftSlot(jobType: .rvPumping),
            ShiftSlot(jobType: .rvFill),
            ShiftSlot(jobType: .toolShed),
            ShiftSlot(jobType: .inventoryManagement)
        ]
        
        return block
    }
}
