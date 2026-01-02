import Foundation
import SwiftUI

// MARK: - User Profile with Privacy Controls
struct UserProfile: Codable, Identifiable {
    let id: String
    
    // Display identity
    var displayName: String          // Playa name / username (always visible)
    var realName: String?            // Real name (private by default)
    var profilePhotoData: Data?      // Profile photo
    
    // Location info
    var homeCity: String?
    var homeCountry: String?
    var campLocation: CampLocation?  // Where they're staying in camp
    
    // Contact info (private, requires request)
    var email: String?
    var phone: String?
    var instagram: String?
    var otherContact: String?
    
    // Privacy settings
    var privacySettings: PrivacySettings
    
    // Metadata
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String,
        displayName: String,
        realName: String? = nil,
        homeCity: String? = nil,
        homeCountry: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.realName = realName
        self.homeCity = homeCity
        self.homeCountry = homeCountry
        self.privacySettings = PrivacySettings()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    var locationText: String? {
        if let city = homeCity, let country = homeCountry {
            return "\(city), \(country)"
        }
        return homeCity ?? homeCountry
    }
    
    var hasContactInfo: Bool {
        email != nil || phone != nil || instagram != nil || otherContact != nil
    }
    
    var initials: String {
        let names = displayName.split(separator: " ")
        if names.count >= 2 {
            return "\(names[0].prefix(1))\(names[1].prefix(1))"
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

// MARK: - Privacy Settings
struct PrivacySettings: Codable, Equatable {
    var showRealName: Bool = false           // Show real name to everyone
    var showLocation: Bool = true            // Show home city
    var showCampLocation: Bool = true        // Show where in camp
    var allowContactRequests: Bool = true    // Allow others to request contact
    var autoApproveContacts: Bool = false    // Auto-approve contact requests
    
    // Who can see what
    var realNameVisibility: Visibility = .approved
    var contactVisibility: Visibility = .approved
    
    enum Visibility: String, Codable, CaseIterable {
        case everyone = "Everyone"
        case approved = "Approved Only"
        case nobody = "Nobody"
    }
}

// MARK: - Camp Location (where in camp)
struct CampLocation: Codable, Equatable {
    var structureID: String?     // ID of RV/tent/structure
    var structureName: String?   // "RV 5", "Tent Row A"
    var xPosition: Double?       // Position on camp map (0-1 normalized)
    var yPosition: Double?
    
    var displayText: String {
        structureName ?? "Unknown"
    }
}

// MARK: - Contact Request
struct ContactRequest: Identifiable, Codable {
    let id: UUID
    let fromMemberID: String
    let fromDisplayName: String
    let toMemberID: String
    let message: String?
    let requestedAt: Date
    var status: RequestStatus
    var respondedAt: Date?
    
    enum RequestStatus: String, Codable {
        case pending = "Pending"
        case approved = "Approved"
        case declined = "Declined"
        case expired = "Expired"
    }
    
    init(
        id: UUID = UUID(),
        fromMemberID: String,
        fromDisplayName: String,
        toMemberID: String,
        message: String? = nil
    ) {
        self.id = id
        self.fromMemberID = fromMemberID
        self.fromDisplayName = fromDisplayName
        self.toMemberID = toMemberID
        self.message = message
        self.requestedAt = Date()
        self.status = .pending
    }
}

// MARK: - Camp Map Structure
struct CampMapStructure: Identifiable, Codable {
    let id: UUID
    var name: String              // "RV 1", "Kitchen", "Shady Bot"
    var type: StructureType
    var xPosition: Double         // 0-1 normalized position on map
    var yPosition: Double
    var assignedMembers: [String] // Member IDs
    var capacity: Int?
    var notes: String?
    
    enum StructureType: String, Codable, CaseIterable {
        case rv = "RV"
        case tent = "Tent"
        case structure = "Structure"
        case kitchen = "Kitchen"
        case bathroom = "Bathroom"
        case stage = "Stage"
        case storage = "Storage"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .rv: return "car.side.fill"
            case .tent: return "tent.fill"
            case .structure: return "building.fill"
            case .kitchen: return "fork.knife"
            case .bathroom: return "toilet.fill"
            case .stage: return "music.note.house.fill"
            case .storage: return "shippingbox.fill"
            case .other: return "mappin.circle.fill"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        type: StructureType,
        xPosition: Double,
        yPosition: Double
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.assignedMembers = []
        self.capacity = nil
        self.notes = nil
    }
}

// MARK: - Camp Map
struct CampMap: Codable {
    var imageData: Data?          // Uploaded camp map image
    var structures: [CampMapStructure]
    var lastUpdated: Date
    
    init() {
        self.structures = []
        self.lastUpdated = Date()
    }
    
    mutating func addStructure(_ structure: CampMapStructure) {
        structures.append(structure)
        lastUpdated = Date()
    }
    
    mutating func removeStructure(_ id: UUID) {
        structures.removeAll { $0.id == id }
        lastUpdated = Date()
    }
    
    mutating func assignMember(_ memberID: String, to structureID: UUID) {
        guard let index = structures.firstIndex(where: { $0.id == structureID }) else { return }
        if !structures[index].assignedMembers.contains(memberID) {
            structures[index].assignedMembers.append(memberID)
        }
        lastUpdated = Date()
    }
    
    func structure(for memberID: String) -> CampMapStructure? {
        structures.first { $0.assignedMembers.contains(memberID) }
    }
}
