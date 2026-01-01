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
        case ice = "[ICE] Ice available at camp"
        case water = "[WATER] Water refill at camp"
        case shift = "[SHIFT] Shift change in 15 minutes"
        case whiteout = "[WHITEOUT] Whiteout conditions - stay put"
        case meet = "[MEET] Meet at the heart"
        case help = "[SOS] Need assistance"
        
        var content: String {
            rawValue
        }
        
        var type: MessageType {
            if rawValue.contains("[SOS]") {
                return .emergency
            } else if rawValue.contains("[SHIFT]") {
                return .shiftUpdate
            } else {
                return .announcement
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
