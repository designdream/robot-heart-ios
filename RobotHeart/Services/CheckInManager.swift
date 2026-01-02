import Foundation
import UserNotifications
import Combine

class CheckInManager: ObservableObject {
    // MARK: - Published Properties
    @Published var lastCheckIn: Date?
    @Published var checkInInterval: TimeInterval = 14400 // 4 hours default
    @Published var isCheckInOverdue: Bool = false
    @Published var memberCheckIns: [String: Date] = [:] // memberID: lastCheckIn
    @Published var overdueMembers: [String] = []
    
    // MARK: - Opt-in Setting (OFF by default - respects burner autonomy)
    @Published var checkInEnabled: Bool = false  // OFF by default
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let lastCheckInKey = "lastCheckIn"
    private let checkInIntervalKey = "checkInInterval"
    private let memberCheckInsKey = "memberCheckIns"
    private let checkInEnabledKey = "checkInEnabled"
    private let currentUserID = "!local"
    private var cancellables = Set<AnyCancellable>()
    private var checkTimer: Timer?
    
    // MARK: - Initialization
    init() {
        loadState()
        // Only start monitoring if user has opted in
        if checkInEnabled {
            startMonitoring()
        }
    }
    
    // MARK: - Enable/Disable Check-In
    func setCheckInEnabled(_ enabled: Bool) {
        checkInEnabled = enabled
        userDefaults.set(enabled, forKey: checkInEnabledKey)
        
        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
            isCheckInOverdue = false
            // Cancel any pending notifications
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["checkin-reminder", "checkin-overdue"]
            )
        }
    }
    
    private func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
    
    // MARK: - Check In
    func checkIn() {
        lastCheckIn = Date()
        isCheckInOverdue = false
        saveState()
        
        // Broadcast check-in to mesh
        NotificationCenter.default.post(
            name: .checkInBroadcast,
            object: CheckInEvent(memberID: currentUserID, timestamp: Date())
        )
        
        // Cancel any overdue notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["checkin-reminder", "checkin-overdue"]
        )
        
        // Schedule next reminder
        scheduleCheckInReminder()
    }
    
    // MARK: - Receive Check-In from Others
    func receiveCheckIn(memberID: String, timestamp: Date) {
        memberCheckIns[memberID] = timestamp
        overdueMembers.removeAll { $0 == memberID }
        saveState()
    }
    
    // MARK: - Set Interval
    func setCheckInInterval(_ interval: TimeInterval) {
        checkInInterval = interval
        userDefaults.set(interval, forKey: checkInIntervalKey)
        
        // Reschedule monitoring
        startMonitoring()
    }
    
    // MARK: - Check Status
    var timeSinceLastCheckIn: TimeInterval {
        guard let last = lastCheckIn else { return .infinity }
        return Date().timeIntervalSince(last)
    }
    
    var checkInStatusText: String {
        guard let last = lastCheckIn else {
            return "Never checked in"
        }
        
        let interval = timeSinceLastCheckIn
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return "\(Int(interval / 3600))h ago"
        }
    }
    
    var nextCheckInDue: Date? {
        guard let last = lastCheckIn else { return nil }
        return last.addingTimeInterval(checkInInterval)
    }
    
    var timeUntilOverdue: TimeInterval {
        guard let due = nextCheckInDue else { return 0 }
        return due.timeIntervalSinceNow
    }
    
    // MARK: - Monitoring
    private func startMonitoring() {
        checkTimer?.invalidate()
        
        // Check every minute
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.evaluateCheckInStatus()
        }
        
        evaluateCheckInStatus()
    }
    
    private func evaluateCheckInStatus() {
        // Check own status
        if let last = lastCheckIn {
            let timeSince = Date().timeIntervalSince(last)
            isCheckInOverdue = timeSince > checkInInterval
        }
        
        // Check other members
        overdueMembers = memberCheckIns.compactMap { memberID, lastCheckIn in
            let timeSince = Date().timeIntervalSince(lastCheckIn)
            return timeSince > checkInInterval ? memberID : nil
        }
    }
    
    // MARK: - Notifications
    private func scheduleCheckInReminder() {
        // Reminder at 75% of interval
        let reminderTime = checkInInterval * 0.75
        
        let reminderContent = UNMutableNotificationContent()
        reminderContent.title = "Check-In Reminder"
        reminderContent.body = "Tap to let your camp know you're OK"
        reminderContent.sound = .default
        reminderContent.categoryIdentifier = "CHECKIN"
        
        let reminderTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderTime,
            repeats: false
        )
        
        let reminderRequest = UNNotificationRequest(
            identifier: "checkin-reminder",
            content: reminderContent,
            trigger: reminderTrigger
        )
        
        // Overdue notification at 100% of interval
        let overdueContent = UNMutableNotificationContent()
        overdueContent.title = "Check-In Overdue"
        overdueContent.body = "Your camp hasn't heard from you. Please check in."
        overdueContent.sound = .defaultCritical
        overdueContent.categoryIdentifier = "CHECKIN"
        
        let overdueTrigger = UNTimeIntervalNotificationTrigger(
            timeInterval: checkInInterval,
            repeats: false
        )
        
        let overdueRequest = UNNotificationRequest(
            identifier: "checkin-overdue",
            content: overdueContent,
            trigger: overdueTrigger
        )
        
        UNUserNotificationCenter.current().add(reminderRequest)
        UNUserNotificationCenter.current().add(overdueRequest)
    }
    
    // MARK: - Persistence
    private func saveState() {
        if let last = lastCheckIn {
            userDefaults.set(last, forKey: lastCheckInKey)
        }
        
        // Encode member check-ins
        if let encoded = try? JSONEncoder().encode(memberCheckIns) {
            userDefaults.set(encoded, forKey: memberCheckInsKey)
        }
    }
    
    private func loadState() {
        lastCheckIn = userDefaults.object(forKey: lastCheckInKey) as? Date
        checkInInterval = userDefaults.double(forKey: checkInIntervalKey)
        if checkInInterval == 0 {
            checkInInterval = 14400 // Default 4 hours
        }
        
        // Load opt-in setting (defaults to false/OFF)
        checkInEnabled = userDefaults.bool(forKey: checkInEnabledKey)
        
        if let data = userDefaults.data(forKey: memberCheckInsKey),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: data) {
            memberCheckIns = decoded
        }
    }
    
    // MARK: - Check-In Event
    struct CheckInEvent {
        let memberID: String
        let timestamp: Date
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let checkInBroadcast = Notification.Name("checkInBroadcast")
}

// MARK: - Interval Options
extension CheckInManager {
    enum IntervalOption: CaseIterable {
        case twoHours
        case fourHours
        case sixHours
        case eightHours
        
        var interval: TimeInterval {
            switch self {
            case .twoHours: return 7200
            case .fourHours: return 14400
            case .sixHours: return 21600
            case .eightHours: return 28800
            }
        }
        
        var title: String {
            switch self {
            case .twoHours: return "2 Hours"
            case .fourHours: return "4 Hours"
            case .sixHours: return "6 Hours"
            case .eightHours: return "8 Hours"
            }
        }
    }
}
