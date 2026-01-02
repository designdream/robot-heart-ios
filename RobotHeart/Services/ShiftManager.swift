import Foundation
import UserNotifications
import Combine

class ShiftManager: ObservableObject {
    // MARK: - Published Properties
    @Published var shifts: [Shift] = []
    @Published var myShifts: [Shift] = []
    @Published var isAdmin: Bool = false
    @Published var notificationsEnabled: Bool = false
    @Published var tradeRequests: [ShiftTrade] = []
    @Published var pendingTradesCount: Int = 0
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let shiftsKey = "savedShifts"
    private let tradesKey = "shiftTrades"
    private let isAdminKey = "isAdmin"
    private let currentUserID = "!local"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Notification Constants
    private let reminderMinutesBefore: TimeInterval = 15 * 60 // 15 minutes
    
    // MARK: - Initialization
    init() {
        loadShifts()
        loadTrades()
        loadAdminStatus()
        checkNotificationPermissions()
        
        // Update myShifts whenever shifts change
        $shifts
            .map { [weak self] shifts in
                shifts.filter { $0.assignedTo == self?.currentUserID }
            }
            .assign(to: &$myShifts)
        
        // Update pending trades count
        $tradeRequests
            .map { [weak self] trades in
                guard let self = self else { return 0 }
                return trades.filter { trade in
                    // Count trades that need my action
                    (trade.offeredTo == self.currentUserID && !trade.receiverApproved && trade.status == .pending) ||
                    (self.isAdmin && !trade.leadApproved && trade.receiverApproved && trade.status == .awaitingLeadApproval)
                }.count
            }
            .assign(to: &$pendingTradesCount)
    }
    
    // MARK: - Notification Permissions
    func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.notificationsEnabled = granted
                if granted {
                    self?.scheduleAllNotifications()
                }
            }
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkNotificationPermissions() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Admin Management
    func setAdminStatus(_ isAdmin: Bool) {
        self.isAdmin = isAdmin
        userDefaults.set(isAdmin, forKey: isAdminKey)
    }
    
    private func loadAdminStatus() {
        isAdmin = userDefaults.bool(forKey: isAdminKey)
    }
    
    // MARK: - Shift CRUD Operations
    func createShift(
        assignedTo: String,
        assigneeName: String,
        location: Shift.ShiftLocation,
        startTime: Date,
        endTime: Date,
        notes: String? = nil
    ) {
        let shift = Shift(
            assignedTo: assignedTo,
            assignedBy: currentUserID,
            assigneeName: assigneeName,
            location: location,
            startTime: startTime,
            endTime: endTime,
            notes: notes
        )
        
        shifts.append(shift)
        saveShifts()
        
        // Schedule notification if this is for the current user
        if assignedTo == currentUserID {
            scheduleNotification(for: shift)
        }
    }
    
    func updateShift(_ shift: Shift) {
        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            // Cancel old notification
            cancelNotification(for: shifts[index])
            
            shifts[index] = shift
            saveShifts()
            
            // Schedule new notification if for current user
            if shift.assignedTo == currentUserID {
                scheduleNotification(for: shift)
            }
        }
    }
    
    func deleteShift(_ shift: Shift) {
        cancelNotification(for: shift)
        shifts.removeAll { $0.id == shift.id }
        saveShifts()
    }
    
    func acknowledgeShift(_ shift: Shift) {
        if let index = shifts.firstIndex(where: { $0.id == shift.id }) {
            var updatedShift = shifts[index]
            updatedShift.acknowledged = true
            shifts[index] = updatedShift
            saveShifts()
        }
    }
    
    // MARK: - Shift Queries
    var upcomingShifts: [Shift] {
        myShifts
            .filter { $0.isUpcoming }
            .sorted { $0.startTime < $1.startTime }
    }
    
    var activeShifts: [Shift] {
        myShifts.filter { $0.isActive }
    }
    
    var pastShifts: [Shift] {
        myShifts
            .filter { $0.isPast }
            .sorted { $0.endTime > $1.endTime }
    }
    
    var nextShift: Shift? {
        upcomingShifts.first
    }
    
    var unacknowledgedShifts: [Shift] {
        myShifts.filter { !$0.acknowledged && !$0.isPast }
    }
    
    func shiftsForMember(_ memberID: String) -> [Shift] {
        shifts
            .filter { $0.assignedTo == memberID }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func shiftsForLocation(_ location: Shift.ShiftLocation) -> [Shift] {
        shifts
            .filter { $0.location == location }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func shiftsForDate(_ date: Date) -> [Shift] {
        let calendar = Calendar.current
        return shifts.filter { shift in
            calendar.isDate(shift.startTime, inSameDayAs: date) ||
            calendar.isDate(shift.endTime, inSameDayAs: date) ||
            (shift.startTime < date && shift.endTime > date)
        }
    }
    
    // MARK: - Notification Scheduling
    private func scheduleNotification(for shift: Shift) {
        guard notificationsEnabled else { return }
        guard shift.isUpcoming else { return }
        
        let notificationTime = shift.startTime.addingTimeInterval(-reminderMinutesBefore)
        guard notificationTime > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Shift Starting Soon"
        content.body = "Your shift at \(shift.location.rawValue) starts in 15 minutes"
        content.sound = .default
        content.categoryIdentifier = "SHIFT_REMINDER"
        content.userInfo = ["shiftID": shift.id.uuidString]
        
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: notificationTime
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: shift.notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelNotification(for shift: Shift) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [shift.notificationIdentifier]
        )
    }
    
    private func scheduleAllNotifications() {
        // Cancel all existing shift notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            let shiftNotificationIDs = requests
                .filter { $0.identifier.hasPrefix("shift-reminder-") }
                .map { $0.identifier }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: shiftNotificationIDs)
            
            // Re-schedule all upcoming shifts for current user
            DispatchQueue.main.async {
                self?.myShifts
                    .filter { $0.isUpcoming }
                    .forEach { self?.scheduleNotification(for: $0) }
            }
        }
    }
    
    // MARK: - Persistence
    private func saveShifts() {
        if let encoded = try? JSONEncoder().encode(shifts) {
            userDefaults.set(encoded, forKey: shiftsKey)
        }
    }
    
    private func loadShifts() {
        if let data = userDefaults.data(forKey: shiftsKey),
           let decoded = try? JSONDecoder().decode([Shift].self, from: data) {
            shifts = decoded
        } else {
            // Load mock data for prototype
            shifts = Shift.mockShifts
        }
    }
    
    private func saveTrades() {
        if let encoded = try? JSONEncoder().encode(tradeRequests) {
            userDefaults.set(encoded, forKey: tradesKey)
        }
    }
    
    private func loadTrades() {
        if let data = userDefaults.data(forKey: tradesKey),
           let decoded = try? JSONDecoder().decode([ShiftTrade].self, from: data) {
            tradeRequests = decoded
        }
    }
    
    // MARK: - Badge Count
    var badgeCount: Int {
        let upcomingWithinHour = upcomingShifts.filter { $0.timeUntilStart < 3600 }.count
        let unacknowledged = unacknowledgedShifts.count
        return upcomingWithinHour + unacknowledged + pendingTradesCount
    }
    
    // MARK: - Shift Trading
    func requestTrade(shift: Shift, to member: CampMember, message: String? = nil) {
        let trade = ShiftTrade(
            shiftID: shift.id,
            shiftDetails: ShiftTrade.ShiftDetails(
                location: shift.location.rawValue,
                startTime: shift.startTime,
                endTime: shift.endTime
            ),
            requestedBy: currentUserID,
            requestedByName: "You",
            offeredTo: member.id,
            offeredToName: member.name,
            message: message
        )
        
        tradeRequests.insert(trade, at: 0)
        saveTrades()
        
        // Broadcast trade request
        NotificationCenter.default.post(
            name: .shiftTradeRequested,
            object: trade
        )
    }
    
    func acceptTrade(_ trade: ShiftTrade) {
        guard let index = tradeRequests.firstIndex(where: { $0.id == trade.id }) else { return }
        
        var updated = tradeRequests[index]
        
        // If I'm the receiver, mark receiver approved
        if trade.offeredTo == currentUserID {
            updated.receiverApproved = true
            updated.status = .awaitingLeadApproval
        }
        
        // If I'm admin/lead, mark lead approved
        if isAdmin {
            updated.leadApproved = true
            updated.leadApprovedBy = currentUserID
        }
        
        // Check if fully approved
        if updated.isFullyApproved {
            updated.status = .approved
            updated.completedAt = Date()
            
            // Execute the trade - reassign the shift
            executeTradeSwap(updated)
        }
        
        tradeRequests[index] = updated
        saveTrades()
    }
    
    func rejectTrade(_ trade: ShiftTrade) {
        guard let index = tradeRequests.firstIndex(where: { $0.id == trade.id }) else { return }
        
        var updated = tradeRequests[index]
        updated.status = .rejected
        updated.completedAt = Date()
        
        tradeRequests[index] = updated
        saveTrades()
    }
    
    func cancelTrade(_ trade: ShiftTrade) {
        guard let index = tradeRequests.firstIndex(where: { $0.id == trade.id }) else { return }
        guard trade.requestedBy == currentUserID else { return }
        
        var updated = tradeRequests[index]
        updated.status = .cancelled
        updated.completedAt = Date()
        
        tradeRequests[index] = updated
        saveTrades()
    }
    
    private func executeTradeSwap(_ trade: ShiftTrade) {
        // Find the shift and reassign it
        if let shiftIndex = shifts.firstIndex(where: { $0.id == trade.shiftID }) {
            var updatedShift = shifts[shiftIndex]
            // Create new shift with new assignee
            let newShift = Shift(
                id: updatedShift.id,
                assignedTo: trade.offeredTo,
                assignedBy: updatedShift.assignedBy,
                assigneeName: trade.offeredToName,
                location: updatedShift.location,
                startTime: updatedShift.startTime,
                endTime: updatedShift.endTime,
                notes: updatedShift.notes,
                acknowledged: false,
                createdAt: updatedShift.createdAt
            )
            shifts[shiftIndex] = newShift
            saveShifts()
            
            // Schedule notification for new assignee
            if trade.offeredTo == currentUserID {
                scheduleNotification(for: newShift)
            }
        }
    }
    
    // MARK: - Trade Queries
    var myPendingTrades: [ShiftTrade] {
        tradeRequests.filter { trade in
            (trade.requestedBy == currentUserID || trade.offeredTo == currentUserID) &&
            (trade.status == .pending || trade.status == .awaitingLeadApproval)
        }
    }
    
    var tradesNeedingMyAction: [ShiftTrade] {
        tradeRequests.filter { trade in
            // I need to accept as receiver
            (trade.offeredTo == currentUserID && !trade.receiverApproved && trade.status == .pending) ||
            // I need to approve as lead
            (isAdmin && !trade.leadApproved && trade.receiverApproved && trade.status == .awaitingLeadApproval)
        }
    }
    
    var tradesNeedingLeadApproval: [ShiftTrade] {
        tradeRequests.filter { $0.status == .awaitingLeadApproval }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let shiftTradeRequested = Notification.Name("shiftTradeRequested")
}

// MARK: - Notification Categories
extension ShiftManager {
    static func registerNotificationCategories() {
        let viewAction = UNNotificationAction(
            identifier: "VIEW_SHIFT",
            title: "View Details",
            options: [.foreground]
        )
        
        let acknowledgeAction = UNNotificationAction(
            identifier: "ACKNOWLEDGE_SHIFT",
            title: "Got It",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "SHIFT_REMINDER",
            actions: [viewAction, acknowledgeAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
