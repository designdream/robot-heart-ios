import Foundation

struct Shift: Identifiable, Codable, Equatable {
    let id: UUID
    let assignedTo: String      // CampMember ID
    let assignedBy: String      // Admin who created it
    let assigneeName: String    // Display name for the assignee
    let location: ShiftLocation
    let startTime: Date
    let endTime: Date
    let notes: String?
    var acknowledged: Bool
    let createdAt: Date
    
    enum ShiftLocation: String, Codable, CaseIterable {
        case bus = "Robot Heart Bus"
        case shadyBot = "Shady Bot"
        case camp = "Camp"
        
        var icon: String {
            switch self {
            case .bus: return "bus.fill"
            case .shadyBot: return "sun.max.fill"
            case .camp: return "tent.fill"
            }
        }
    }
    
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var isUpcoming: Bool {
        Date() < startTime
    }
    
    var isPast: Bool {
        Date() > endTime
    }
    
    var timeUntilStart: TimeInterval {
        startTime.timeIntervalSinceNow
    }
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
    
    var durationText: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var statusText: String {
        if isActive {
            return "Active Now"
        } else if isUpcoming {
            let interval = timeUntilStart
            if interval < 3600 {
                return "Starts in \(Int(interval / 60))m"
            } else if interval < 86400 {
                return "Starts in \(Int(interval / 3600))h"
            } else {
                return "In \(Int(interval / 86400)) days"
            }
        } else {
            return "Completed"
        }
    }
    
    var notificationIdentifier: String {
        "shift-reminder-\(id.uuidString)"
    }
    
    init(
        id: UUID = UUID(),
        assignedTo: String,
        assignedBy: String,
        assigneeName: String,
        location: ShiftLocation,
        startTime: Date,
        endTime: Date,
        notes: String? = nil,
        acknowledged: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assignedTo = assignedTo
        self.assignedBy = assignedBy
        self.assigneeName = assigneeName
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.acknowledged = acknowledged
        self.createdAt = createdAt
    }
}

// MARK: - Mock Data
extension Shift {
    static let mockShifts: [Shift] = [
        Shift(
            assignedTo: "!local",
            assignedBy: "!a1b2c3d4",
            assigneeName: "You",
            location: .bus,
            startTime: Date().addingTimeInterval(900), // 15 min from now
            endTime: Date().addingTimeInterval(7200),   // 2 hours from now
            notes: "Opening set support"
        ),
        Shift(
            assignedTo: "!local",
            assignedBy: "!a1b2c3d4",
            assigneeName: "You",
            location: .shadyBot,
            startTime: Date().addingTimeInterval(86400), // Tomorrow
            endTime: Date().addingTimeInterval(86400 + 10800),
            notes: nil
        ),
        Shift(
            assignedTo: "!e5f6g7h8",
            assignedBy: "!a1b2c3d4",
            assigneeName: "Jordan",
            location: .bus,
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(3600),
            notes: "Sunrise set",
            acknowledged: true
        ),
        Shift(
            assignedTo: "!i9j0k1l2",
            assignedBy: "!a1b2c3d4",
            assigneeName: "Sam",
            location: .shadyBot,
            startTime: Date().addingTimeInterval(-1800),
            endTime: Date().addingTimeInterval(5400),
            notes: nil,
            acknowledged: true
        )
    ]
}
