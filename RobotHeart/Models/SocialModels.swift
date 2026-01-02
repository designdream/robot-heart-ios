import Foundation
import CoreImage
import SwiftUI

// MARK: - Private Notes on Members
struct MemberNote: Identifiable, Codable {
    let id: UUID
    let memberID: String           // Who the note is about
    var content: String
    var tags: [String]             // e.g., "met at", "interests", "follow up"
    var metAt: String?             // Where you met them
    var createdAt: Date
    var updatedAt: Date
    
    init(memberID: String, content: String, tags: [String] = [], metAt: String? = nil) {
        self.id = UUID()
        self.memberID = memberID
        self.content = content
        self.tags = tags
        self.metAt = metAt
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Contact Card for QR Exchange
struct ContactCard: Codable {
    let id: String                 // Member ID
    let displayName: String
    let realName: String?
    let homeCity: String?
    let homeCountry: String?
    let email: String?
    let phone: String?
    let instagram: String?
    let campName: String           // "Robot Heart"
    let year: Int                  // Burn year
    let createdAt: Date
    
    var qrData: Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func from(data: Data) -> ContactCard? {
        try? JSONDecoder().decode(ContactCard.self, from: data)
    }
}

// MARK: - Playa Event
struct PlayaEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var location: EventLocation
    var startTime: Date
    var endTime: Date?
    var category: EventCategory
    var hostCamp: String?
    var createdBy: String          // Member ID
    var createdByName: String
    var isPublic: Bool             // Visible to all or just camp
    var attendees: [String]        // Member IDs
    var createdAt: Date
    var updatedAt: Date
    
    enum EventCategory: String, Codable, CaseIterable {
        case music = "Music"
        case art = "Art"
        case workshop = "Workshop"
        case food = "Food & Drink"
        case ceremony = "Ceremony"
        case party = "Party"
        case wellness = "Wellness"
        case community = "Community"
        case other = "Other"
        
        var icon: String {
            switch self {
            case .music: return "music.note"
            case .art: return "paintpalette.fill"
            case .workshop: return "hammer.fill"
            case .food: return "fork.knife"
            case .ceremony: return "flame.fill"
            case .party: return "sparkles"
            case .wellness: return "heart.circle.fill"
            case .community: return "person.3.fill"
            case .other: return "star.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .music: return Theme.Colors.sunsetOrange
            case .art: return Theme.Colors.dustyPink
            case .workshop: return Theme.Colors.goldenYellow
            case .food: return Theme.Colors.amber
            case .ceremony: return Theme.Colors.deepRedOrange
            case .party: return Theme.Colors.ledMagenta
            case .wellness: return Theme.Colors.turquoise
            case .community: return Theme.Colors.playaDust
            case .other: return Theme.Colors.robotCream
            }
        }
    }
    
    struct EventLocation: Codable {
        var name: String           // "Robot Heart", "2:00 & Esplanade"
        var clockPosition: String? // "2:00"
        var street: String?        // "Esplanade"
        var latitude: Double?
        var longitude: Double?
        
        var displayText: String {
            if let clock = clockPosition, let street = street {
                return "\(clock) & \(street)"
            }
            return name
        }
    }
    
    init(
        title: String,
        description: String,
        location: EventLocation,
        startTime: Date,
        endTime: Date? = nil,
        category: EventCategory,
        hostCamp: String? = nil,
        createdBy: String,
        createdByName: String,
        isPublic: Bool = true
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.location = location
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.hostCamp = hostCamp
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.isPublic = isPublic
        self.attendees = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Knowledge Base Article
struct KnowledgeArticle: Identifiable, Codable {
    let id: UUID
    var title: String
    var content: String            // Markdown supported
    var category: ArticleCategory
    var tags: [String]
    var author: String
    var authorName: String
    var isPinned: Bool
    var viewCount: Int
    var createdAt: Date
    var updatedAt: Date
    
    enum ArticleCategory: String, Codable, CaseIterable {
        case survival = "Survival"
        case firstTime = "First Timers"
        case campDuties = "Camp Duties"
        case shiftGuide = "Shift Guide"
        case safety = "Safety"
        case art = "Art & Music"
        case community = "Community"
        case logistics = "Logistics"
        case faq = "FAQ"
        
        var icon: String {
            switch self {
            case .survival: return "flame.fill"
            case .firstTime: return "star.fill"
            case .campDuties: return "list.clipboard.fill"
            case .shiftGuide: return "calendar.badge.clock"
            case .safety: return "cross.case.fill"
            case .art: return "music.note.house.fill"
            case .community: return "heart.fill"
            case .logistics: return "shippingbox.fill"
            case .faq: return "questionmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .survival: return Theme.Colors.sunsetOrange
            case .firstTime: return Theme.Colors.goldenYellow
            case .campDuties: return Theme.Colors.turquoise
            case .shiftGuide: return Theme.Colors.dustyPink
            case .safety: return Theme.Colors.emergency
            case .art: return Theme.Colors.ledMagenta
            case .community: return Theme.Colors.sunsetOrange
            case .logistics: return Theme.Colors.playaDust
            case .faq: return Theme.Colors.info
            }
        }
    }
    
    init(
        title: String,
        content: String,
        category: ArticleCategory,
        tags: [String] = [],
        author: String,
        authorName: String
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.category = category
        self.tags = tags
        self.author = author
        self.authorName = authorName
        self.isPinned = false
        self.viewCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Scanned Contact (from QR)
struct ScannedContact: Identifiable, Codable {
    let id: UUID
    let contactCard: ContactCard
    var note: String?
    var scannedAt: Date
    
    init(contactCard: ContactCard, note: String? = nil) {
        self.id = UUID()
        self.contactCard = contactCard
        self.note = note
        self.scannedAt = Date()
    }
}
