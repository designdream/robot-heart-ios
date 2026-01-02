import Foundation

struct Message: Identifiable, Codable {
    let id: String
    let from: String // Node ID
    let fromName: String
    let content: String
    let timestamp: Date
    let messageType: MessageType
    let deliveryStatus: DeliveryStatus
    let location: CampMember.Location?
    
    enum MessageType: String, Codable {
        case text = "TEXT"
        case announcement = "ANNOUNCEMENT"
        case emergency = "EMERGENCY"
        case locationShare = "LOCATION"
        case shiftUpdate = "SHIFT"
        
        var tag: String? {
            switch self {
            case .announcement: return "[CAMP]"
            case .emergency: return "[SOS]"
            case .locationShare: return "[LOC]"
            case .shiftUpdate: return "[SHIFT]"
            case .text: return nil
            }
        }
        
        var icon: String {
            switch self {
            case .text: return "message.fill"
            case .announcement: return "megaphone.fill"
            case .emergency: return "exclamationmark.triangle.fill"
            case .locationShare: return "location.fill"
            case .shiftUpdate: return "clock.fill"
            }
        }
        
        var color: String {
            switch self {
            case .text: return "blue"
            case .announcement: return "orange"
            case .emergency: return "red"
            case .locationShare: return "green"
            case .shiftUpdate: return "purple"
            }
        }
    }
    
    enum DeliveryStatus: String, Codable {
        case queued = "Queued"
        case sent = "Sent"
        case delivered = "Delivered"
        case failed = "Failed"
        
        var icon: String {
            switch self {
            case .queued: return "clock"
            case .sent: return "checkmark"
            case .delivered: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
    
    var displayContent: String {
        if let tag = messageType.tag {
            return "\(tag) \(content)"
        }
        return content
    }
}

// MARK: - Message Templates
extension Message {
    enum Template: String, CaseIterable {
        // Quick status updates
        case onMyWay = "On my way! 🚶"
        case running5Late = "Running 5 min late"
        case running15Late = "Running 15 min late"
        case atLocation = "I'm here! 📍"
        case shiftStarting = "Starting my shift now"
        case shiftEnding = "Shift complete ✅"
        // Coordination
        case meetAtBus = "Meet at the bus?"
        case meetAtCamp = "Meet at camp?"
        case whereIsEveryone = "Where is everyone?"
        // Resources
        case waterBreak = "Water break! 💧"
        case iceAvailable = "Ice available at camp 🧊"
        // Help
        case needHelp = "Need help at my location"
        case allGood = "All good here 👍"
        
        var content: String { rawValue }
        
        var type: MessageType {
            if rawValue.contains("Need help") {
                return .emergency
            } else if rawValue.contains("shift") {
                return .shiftUpdate
            } else {
                return .text
            }
        }
    }
}

// MARK: - Mock Data
extension Message {
    static let mockMessages: [Message] = [
        Message(
            id: UUID().uuidString,
            from: "!a1b2c3d4",
            fromName: "Alex",
            content: "Heading to the bus for my shift",
            timestamp: Date().addingTimeInterval(-3600),
            messageType: .text,
            deliveryStatus: .delivered,
            location: nil
        ),
        Message(
            id: UUID().uuidString,
            from: "!e5f6g7h8",
            fromName: "Jordan",
            content: "Ice available at camp",
            timestamp: Date().addingTimeInterval(-1800),
            messageType: .announcement,
            deliveryStatus: .delivered,
            location: nil
        ),
        Message(
            id: UUID().uuidString,
            from: "!i9j0k1l2",
            fromName: "Sam",
            content: "Shift change in 15 minutes",
            timestamp: Date().addingTimeInterval(-900),
            messageType: .shiftUpdate,
            deliveryStatus: .sent,
            location: nil
        )
    ]
}
