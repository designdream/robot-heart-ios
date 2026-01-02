import Foundation
import CoreLocation

struct CampMember: Identifiable, Codable, Hashable {
    let id: String // Meshtastic node ID
    var name: String
    var role: Role
    var location: Location?
    var lastSeen: Date
    var batteryLevel: Int?
    var status: ConnectionStatus
    var currentShift: Shift?
    
    // Hashable conformance based on unique ID
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CampMember, rhs: CampMember) -> Bool {
        lhs.id == rhs.id
    }
    
    enum Role: String, Codable, CaseIterable {
        case lead = "Lead"
        case bus = "Bus Crew"
        case shadyBot = "Shady Bot"
        case build = "Build"
        case med = "Med"
        case perimeter = "Perimeter"
        case bike = "Bike Team"
        case general = "General"
        
        var icon: String {
            switch self {
            case .lead: return "star.fill"
            case .bus: return "bus.fill"
            case .shadyBot: return "sun.max.fill"
            case .build: return "hammer.fill"
            case .med: return "cross.fill"
            case .perimeter: return "shield.fill"
            case .bike: return "bicycle"
            case .general: return "person.fill"
            }
        }
    }
    
    enum ConnectionStatus: String, Codable {
        case connected = "Connected"
        case recent = "Recent"
        case offline = "Offline"
        
        var color: String {
            switch self {
            case .connected: return "green"
            case .recent: return "orange"
            case .offline: return "red"
            }
        }
    }
    
    struct Location: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
        let accuracy: Double?
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    struct Shift: Codable {
        let location: ShiftLocation
        let startTime: Date
        let endTime: Date
        
        enum ShiftLocation: String, Codable {
            case bus = "Robot Heart Bus"
            case shadyBot = "Shady Bot"
            case camp = "Camp"
        }
        
        var isActive: Bool {
            let now = Date()
            return now >= startTime && now <= endTime
        }
    }
    
    var isOnline: Bool {
        status == .connected || (status == .recent && lastSeen.timeIntervalSinceNow > -300)
    }
    
    var lastSeenText: String {
        let interval = Date().timeIntervalSince(lastSeen)
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

// MARK: - Mock Data
extension CampMember {
    static let mockMembers: [CampMember] = [
        CampMember(
            id: "!a1b2c3d4",
            name: "Alex",
            role: .lead,
            location: Location(latitude: 40.7864, longitude: -119.2065, timestamp: Date(), accuracy: 10),
            lastSeen: Date(),
            batteryLevel: 85,
            status: .connected,
            currentShift: nil
        ),
        CampMember(
            id: "!e5f6g7h8",
            name: "Jordan",
            role: .bus,
            location: Location(latitude: 40.7865, longitude: -119.2066, timestamp: Date().addingTimeInterval(-300), accuracy: 15),
            lastSeen: Date().addingTimeInterval(-300),
            batteryLevel: 62,
            status: .recent,
            currentShift: Shift(location: .bus, startTime: Date().addingTimeInterval(-3600), endTime: Date().addingTimeInterval(3600))
        ),
        CampMember(
            id: "!i9j0k1l2",
            name: "Sam",
            role: .shadyBot,
            location: Location(latitude: 40.7866, longitude: -119.2067, timestamp: Date().addingTimeInterval(-600), accuracy: 20),
            lastSeen: Date().addingTimeInterval(-600),
            batteryLevel: 45,
            status: .recent,
            currentShift: Shift(location: .shadyBot, startTime: Date().addingTimeInterval(-1800), endTime: Date().addingTimeInterval(5400))
        ),
        CampMember(
            id: "!m3n4o5p6",
            name: "Taylor",
            role: .bike,
            location: nil,
            lastSeen: Date().addingTimeInterval(-7200),
            batteryLevel: nil,
            status: .offline,
            currentShift: nil
        )
    ]
}
