import Foundation
import UserNotifications

class AnnouncementManager: ObservableObject {
    // MARK: - Published Properties
    @Published var announcements: [Announcement] = []
    @Published var unreadCount: Int = 0
    @Published var latestAnnouncement: Announcement?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let announcementsKey = "announcements"
    private let currentUserID = "!local"
    
    // MARK: - Initialization
    init() {
        loadAnnouncements()
        updateUnreadCount()
    }
    
    // MARK: - Announcement Model
    struct Announcement: Identifiable, Codable, Equatable {
        let id: UUID
        let fromID: String
        let fromName: String
        let title: String
        let message: String
        let priority: Priority
        let timestamp: Date
        var readBy: [String]
        let expiresAt: Date?
        
        enum Priority: String, Codable, CaseIterable {
            case normal = "Normal"
            case important = "Important"
            case urgent = "Urgent"
            
            var icon: String {
                switch self {
                case .normal: return "megaphone.fill"
                case .important: return "exclamationmark.circle.fill"
                case .urgent: return "exclamationmark.triangle.fill"
                }
            }
            
            var color: String {
                switch self {
                case .normal: return "turquoise"
                case .important: return "sunsetOrange"
                case .urgent: return "emergency"
                }
            }
        }
        
        init(
            id: UUID = UUID(),
            fromID: String,
            fromName: String,
            title: String,
            message: String,
            priority: Priority = .normal,
            timestamp: Date = Date(),
            readBy: [String] = [],
            expiresAt: Date? = nil
        ) {
            self.id = id
            self.fromID = fromID
            self.fromName = fromName
            self.title = title
            self.message = message
            self.priority = priority
            self.timestamp = timestamp
            self.readBy = readBy
            self.expiresAt = expiresAt
        }
        
        var isExpired: Bool {
            if let expires = expiresAt {
                return Date() > expires
            }
            return false
        }
        
        var timeAgoText: String {
            let interval = Date().timeIntervalSince(timestamp)
            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                return "\(Int(interval / 60))m ago"
            } else if interval < 86400 {
                return "\(Int(interval / 3600))h ago"
            } else {
                return "\(Int(interval / 86400))d ago"
            }
        }
    }
    
    // MARK: - Send Announcement (Admin only)
    func sendAnnouncement(
        title: String,
        message: String,
        priority: Announcement.Priority = .normal,
        expiresIn: TimeInterval? = nil
    ) {
        let announcement = Announcement(
            fromID: currentUserID,
            fromName: "You",
            title: title,
            message: message,
            priority: priority,
            readBy: [currentUserID],
            expiresAt: expiresIn.map { Date().addingTimeInterval($0) }
        )
        
        announcements.insert(announcement, at: 0)
        saveAnnouncements()
        
        // Broadcast via mesh
        NotificationCenter.default.post(
            name: .announcementBroadcast,
            object: announcement
        )
    }
    
    // MARK: - Receive Announcement
    func receiveAnnouncement(_ announcement: Announcement) {
        announcements.insert(announcement, at: 0)
        latestAnnouncement = announcement
        saveAnnouncements()
        updateUnreadCount()
        
        // Send local notification
        sendAnnouncementNotification(announcement)
    }
    
    // MARK: - Mark as Read
    func markAsRead(_ announcement: Announcement) {
        if let index = announcements.firstIndex(where: { $0.id == announcement.id }) {
            var updated = announcements[index]
            if !updated.readBy.contains(currentUserID) {
                updated.readBy.append(currentUserID)
                announcements[index] = updated
                saveAnnouncements()
                updateUnreadCount()
            }
        }
        
        if latestAnnouncement?.id == announcement.id {
            latestAnnouncement = nil
        }
    }
    
    // MARK: - Mark All as Read
    func markAllAsRead() {
        for i in 0..<announcements.count {
            if !announcements[i].readBy.contains(currentUserID) {
                announcements[i].readBy.append(currentUserID)
            }
        }
        saveAnnouncements()
        updateUnreadCount()
        latestAnnouncement = nil
    }
    
    // MARK: - Dismiss Latest
    func dismissLatest() {
        if let latest = latestAnnouncement {
            markAsRead(latest)
        }
        latestAnnouncement = nil
    }
    
    // MARK: - Active Announcements
    var activeAnnouncements: [Announcement] {
        announcements.filter { !$0.isExpired }
    }
    
    var unreadAnnouncements: [Announcement] {
        announcements.filter { !$0.readBy.contains(currentUserID) && !$0.isExpired }
    }
    
    // MARK: - Notifications
    private func sendAnnouncementNotification(_ announcement: Announcement) {
        let content = UNMutableNotificationContent()
        content.title = announcement.priority == .urgent ? "🚨 \(announcement.title)" : "📢 \(announcement.title)"
        content.body = announcement.message
        content.sound = announcement.priority == .urgent ? .defaultCritical : .default
        content.categoryIdentifier = "ANNOUNCEMENT"
        
        let request = UNNotificationRequest(
            identifier: "announcement-\(announcement.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Persistence
    private func saveAnnouncements() {
        let toSave = Array(announcements.prefix(100))
        if let encoded = try? JSONEncoder().encode(toSave) {
            userDefaults.set(encoded, forKey: announcementsKey)
        }
    }
    
    private func loadAnnouncements() {
        if let data = userDefaults.data(forKey: announcementsKey),
           let decoded = try? JSONDecoder().decode([Announcement].self, from: data) {
            announcements = decoded.filter { !$0.isExpired }
        } else {
            // Load mock data
            announcements = Announcement.mockAnnouncements
        }
    }
    
    private func updateUnreadCount() {
        unreadCount = unreadAnnouncements.count
    }
}

// MARK: - Mock Data
extension AnnouncementManager.Announcement {
    static let mockAnnouncements: [AnnouncementManager.Announcement] = [
        AnnouncementManager.Announcement(
            fromID: "!a1b2c3d4",
            fromName: "Alex",
            title: "Art Car Leaving",
            message: "Robot Heart bus leaving for deep playa in 30 minutes. Meet at camp entrance.",
            priority: .important,
            timestamp: Date().addingTimeInterval(-1800)
        ),
        AnnouncementManager.Announcement(
            fromID: "!a1b2c3d4",
            fromName: "Alex",
            title: "Ice Available",
            message: "Fresh ice delivery at camp. Come grab some before it melts!",
            priority: .normal,
            timestamp: Date().addingTimeInterval(-7200)
        )
    ]
}

// MARK: - Notification Names
extension Notification.Name {
    static let announcementBroadcast = Notification.Name("announcementBroadcast")
}
