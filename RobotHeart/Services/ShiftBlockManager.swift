import Foundation
import Combine
import UserNotifications

class ShiftBlockManager: ObservableObject {
    // MARK: - Published Properties
    @Published var schedule: ShiftSchedule
    @Published var selectedDate: Date = Date()
    @Published var viewMode: ViewMode = .day
    @Published var isAdmin: Bool = false
    
    enum ViewMode {
        case day
        case week
    }
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let scheduleKey = "shiftSchedule"
    private let isAdminKey = "isAdmin"
    private let currentUserID = "!local"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Default to Burning Man week (placeholder dates)
        let eventStart = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30))!
        let eventEnd = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 7))!
        
        schedule = ShiftSchedule(eventStartDate: eventStart, eventEndDate: eventEnd)
        
        loadSchedule()
        loadAdminStatus()
    }
    
    // MARK: - View Helpers
    var blocksForSelectedDate: [ShiftBlock] {
        schedule.blocks(for: selectedDate)
    }
    
    var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    func blocksForDate(_ date: Date) -> [ShiftBlock] {
        schedule.blocks(for: date)
    }
    
    // MARK: - My Shifts
    var myShiftBlocks: [ShiftBlock] {
        schedule.blocks.filter { $0.hasMember(currentUserID) }
    }
    
    var myUpcomingShifts: [ShiftBlock] {
        myShiftBlocks.filter { $0.startTime > Date() }.sorted { $0.startTime < $1.startTime }
    }
    
    var myTotalPoints: Int {
        myShiftBlocks.reduce(0) { total, block in
            let mySlots = block.slots.filter { $0.assignedTo == currentUserID }
            return total + mySlots.reduce(0) { $0 + $1.pointValue }
        }
    }
    
    // MARK: - Admin: Create Shift Block
    func createBlock(
        location: Shift.ShiftLocation,
        startTime: Date,
        endTime: Date,
        slots: [ShiftSlot],
        notes: String? = nil
    ) -> ShiftBlock {
        let block = ShiftBlock(
            location: location,
            startTime: startTime,
            endTime: endTime,
            slots: slots,
            createdBy: currentUserID,
            notes: notes
        )
        
        schedule.blocks.append(block)
        saveSchedule()
        
        return block
    }
    
    func createFromTemplate(_ template: ShiftBlockTemplate, startTime: Date, endTime: Date) -> ShiftBlock {
        var block: ShiftBlock
        
        switch template {
        case .bus:
            block = ShiftBlock.busShiftTemplate(startTime: startTime, endTime: endTime, createdBy: currentUserID)
        case .camp:
            block = ShiftBlock.campShiftTemplate(startTime: startTime, endTime: endTime, createdBy: currentUserID)
        case .infrastructure:
            block = ShiftBlock.infrastructureShiftTemplate(startTime: startTime, endTime: endTime, createdBy: currentUserID)
        }
        
        schedule.blocks.append(block)
        saveSchedule()
        
        return block
    }
    
    enum ShiftBlockTemplate {
        case bus
        case camp
        case infrastructure
    }
    
    // MARK: - Admin: Add Slot to Block
    func addSlot(to blockID: UUID, jobType: ShiftJobType) {
        guard let index = schedule.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        
        let slot = ShiftSlot(jobType: jobType)
        schedule.blocks[index].slots.append(slot)
        saveSchedule()
    }
    
    func removeSlot(from blockID: UUID, slotID: UUID) {
        guard let index = schedule.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        
        schedule.blocks[index].slots.removeAll { $0.id == slotID }
        saveSchedule()
    }
    
    // MARK: - Admin: Release Block
    func releaseBlock(_ blockID: UUID) {
        guard let index = schedule.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        
        schedule.blocks[index].release(by: currentUserID)
        saveSchedule()
        
        // Notify members
        notifyBlockReleased(schedule.blocks[index])
    }
    
    func releaseAllBlocks(for date: Date) {
        let calendar = Calendar.current
        for i in 0..<schedule.blocks.count {
            if calendar.isDate(schedule.blocks[i].startTime, inSameDayAs: date) {
                schedule.blocks[i].release(by: currentUserID)
            }
        }
        saveSchedule()
    }
    
    // MARK: - Member: Claim Slot
    func claimSlot(blockID: UUID, slotID: UUID, memberName: String = "You") -> (success: Bool, message: String) {
        guard let blockIndex = schedule.blocks.firstIndex(where: { $0.id == blockID }) else {
            return (false, "Shift not found")
        }
        
        let block = schedule.blocks[blockIndex]
        
        // Check if released
        guard block.isReleased else {
            return (false, "This shift hasn't been released yet")
        }
        
        // Check 24-hour rule
        let (canClaim, reason) = schedule.canMemberClaim(currentUserID, block: block)
        if !canClaim {
            return (false, reason ?? "Cannot claim this shift")
        }
        
        // Check if already on this shift
        if block.hasMember(currentUserID) {
            return (false, "You're already on this shift")
        }
        
        // Claim the slot
        let success = schedule.blocks[blockIndex].claimSlot(slotID, by: currentUserID, name: memberName)
        
        if success {
            saveSchedule()
            scheduleReminder(for: schedule.blocks[blockIndex])
            return (true, "Slot claimed successfully!")
        }
        
        return (false, "This slot is no longer available")
    }
    
    // MARK: - Member: Release My Slot
    func releaseMySlot(blockID: UUID, slotID: UUID) {
        guard let blockIndex = schedule.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        guard let slotIndex = schedule.blocks[blockIndex].slots.firstIndex(where: { $0.id == slotID }) else { return }
        
        // Only allow if it's my slot
        guard schedule.blocks[blockIndex].slots[slotIndex].assignedTo == currentUserID else { return }
        
        schedule.blocks[blockIndex].releaseSlot(slotID)
        saveSchedule()
    }
    
    // MARK: - Admin Status
    func setAdminStatus(_ isAdmin: Bool) {
        self.isAdmin = isAdmin
        userDefaults.set(isAdmin, forKey: isAdminKey)
    }
    
    private func loadAdminStatus() {
        isAdmin = userDefaults.bool(forKey: isAdminKey)
    }
    
    // MARK: - Notifications
    private func scheduleReminder(for block: ShiftBlock) {
        let content = UNMutableNotificationContent()
        content.title = "Shift Reminder"
        content.body = "Your \(block.location.rawValue) shift starts in 15 minutes"
        content.sound = .default
        
        let reminderTime = block.startTime.addingTimeInterval(-15 * 60)
        guard reminderTime > Date() else { return }
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "shift-block-\(block.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyBlockReleased(_ block: ShiftBlock) {
        let content = UNMutableNotificationContent()
        content.title = "New Shifts Available!"
        content.body = "\(block.location.rawValue) shift on \(block.dayText) is now open for claiming"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "block-released-\(block.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Persistence
    private func saveSchedule() {
        if let encoded = try? JSONEncoder().encode(schedule) {
            userDefaults.set(encoded, forKey: scheduleKey)
        }
    }
    
    private func loadSchedule() {
        if let data = userDefaults.data(forKey: scheduleKey),
           let decoded = try? JSONDecoder().decode(ShiftSchedule.self, from: data) {
            schedule = decoded
        } else {
            // Load mock data
            loadMockSchedule()
        }
    }
    
    // MARK: - Mock Data
    private func loadMockSchedule() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Create some sample blocks
        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            
            // Morning bus shift
            if let morningStart = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
               let morningEnd = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: day) {
                var block = ShiftBlock.busShiftTemplate(startTime: morningStart, endTime: morningEnd, createdBy: "admin")
                block.release(by: "admin")
                schedule.blocks.append(block)
            }
            
            // Evening bus shift
            if let eveningStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day),
               let eveningEnd = calendar.date(bySettingHour: 2, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 1, to: day)!) {
                var block = ShiftBlock.busShiftTemplate(startTime: eveningStart, endTime: eveningEnd, createdBy: "admin")
                if dayOffset < 3 {
                    block.release(by: "admin")
                }
                schedule.blocks.append(block)
            }
            
            // Camp shift
            if let campStart = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day),
               let campEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) {
                var block = ShiftBlock.campShiftTemplate(startTime: campStart, endTime: campEnd, createdBy: "admin")
                block.release(by: "admin")
                schedule.blocks.append(block)
            }
        }
    }
}
