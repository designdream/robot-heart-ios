import Foundation

// MARK: - User Role System
/// Defines the different types of users in the Robot Heart ecosystem.
///
/// The app serves multiple audiences:
/// - **Fans**: Follow Robot Heart, attend public events, buy merch
/// - **Volunteers**: Help at year-round events (Residency, Miami Art Basel, etc.)
/// - **Camp Members**: Full camp members who attend Burning Man
/// - **Leads**: Camp leads with admin privileges
/// - **Admins**: Full system access, can switch between all roles
///
/// Each role unlocks different features via feature flags.

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case fan = "Fan"
    case volunteer = "Volunteer"
    case campMember = "Camp Member"
    case lead = "Lead"
    case admin = "Admin"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .fan: return "heart.fill"
        case .volunteer: return "hands.sparkles.fill"
        case .campMember: return "tent.fill"
        case .lead: return "star.fill"
        case .admin: return "gearshape.fill"
        }
    }
    
    var description: String {
        switch self {
        case .fan:
            return "Follow Robot Heart events, music, and community updates"
        case .volunteer:
            return "Help at year-round events like Residency and Art Basel"
        case .campMember:
            return "Full camp member with shifts, tasks, and playa features"
        case .lead:
            return "Camp lead with admin tools and member management"
        case .admin:
            return "Full system access with role switching for testing"
        }
    }
    
    var color: String {
        switch self {
        case .fan: return "dustyPink"
        case .volunteer: return "turquoise"
        case .campMember: return "goldenYellow"
        case .lead: return "sunsetOrange"
        case .admin: return "ledMagenta"
        }
    }
    
    /// Hierarchy level for permission checks
    var level: Int {
        switch self {
        case .fan: return 0
        case .volunteer: return 1
        case .campMember: return 2
        case .lead: return 3
        case .admin: return 4
        }
    }
    
    /// Check if this role has at least the permissions of another role
    func hasPermission(of role: UserRole) -> Bool {
        self.level >= role.level
    }
}

// MARK: - Feature Flags
/// Feature flags that control what's visible/accessible based on user role.
///
/// Features are grouped by category and each has a minimum role requirement.
/// Admins can override to experience any role's view.

struct FeatureFlags: Codable {
    
    // MARK: - Feature Categories
    
    enum Feature: String, CaseIterable, Identifiable {
        // Fan Features (everyone)
        case viewEvents = "View Events"
        case viewMusic = "View Music/Sets"
        case viewMerch = "View Merchandise"
        case viewNews = "View News & Updates"
        case socialCapitalView = "View Social Capital"
        
        // Volunteer Features
        case volunteerShifts = "Volunteer Shifts"
        case volunteerTasks = "Volunteer Tasks"
        case eventCheckIn = "Event Check-In"
        case volunteerChat = "Volunteer Chat"
        
        // Camp Member Features
        case campShifts = "Camp Shifts"
        case campTasks = "Camp Tasks"
        case campLayout = "Camp Layout Planner"
        case campRoster = "Camp Roster"
        case campChat = "Camp Messaging"
        case playaMap = "Playa Map"
        case draftParticipation = "Shift Draft"
        case safetyFeatures = "Safety (SOS, Check-ins)"
        
        // Lead Features
        case memberManagement = "Member Management"
        case shiftCreation = "Create/Edit Shifts"
        case taskCreation = "Create/Edit Tasks"
        case announcements = "Send Announcements"
        case campSettings = "Camp Settings"
        case viewReports = "View Reports"
        
        // Admin Features
        case roleSwitcher = "Role Switcher"
        case allCampAccess = "Access All Camps"
        case systemSettings = "System Settings"
        case featureFlagOverride = "Feature Flag Override"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .viewEvents: return "calendar"
            case .viewMusic: return "music.note"
            case .viewMerch: return "bag.fill"
            case .viewNews: return "newspaper.fill"
            case .socialCapitalView: return "heart.circle.fill"
            case .volunteerShifts: return "clock.fill"
            case .volunteerTasks: return "checklist"
            case .eventCheckIn: return "checkmark.circle.fill"
            case .volunteerChat: return "bubble.left.and.bubble.right.fill"
            case .campShifts: return "calendar.badge.clock"
            case .campTasks: return "checkmark.circle"
            case .campLayout: return "map.fill"
            case .campRoster: return "person.3.fill"
            case .campChat: return "message.fill"
            case .playaMap: return "location.fill"
            case .draftParticipation: return "sportscourt.fill"
            case .safetyFeatures: return "shield.fill"
            case .memberManagement: return "person.badge.plus"
            case .shiftCreation: return "plus.circle.fill"
            case .taskCreation: return "plus.square.fill"
            case .announcements: return "megaphone.fill"
            case .campSettings: return "gearshape.fill"
            case .viewReports: return "chart.bar.fill"
            case .roleSwitcher: return "arrow.triangle.2.circlepath"
            case .allCampAccess: return "building.2.fill"
            case .systemSettings: return "wrench.and.screwdriver.fill"
            case .featureFlagOverride: return "flag.fill"
            }
        }
        
        /// Minimum role required to access this feature
        var minimumRole: UserRole {
            switch self {
            // Fan features
            case .viewEvents, .viewMusic, .viewMerch, .viewNews, .socialCapitalView:
                return .fan
                
            // Volunteer features
            case .volunteerShifts, .volunteerTasks, .eventCheckIn, .volunteerChat:
                return .volunteer
                
            // Camp member features
            case .campShifts, .campTasks, .campLayout, .campRoster, .campChat,
                 .playaMap, .draftParticipation, .safetyFeatures:
                return .campMember
                
            // Lead features
            case .memberManagement, .shiftCreation, .taskCreation, .announcements,
                 .campSettings, .viewReports:
                return .lead
                
            // Admin features
            case .roleSwitcher, .allCampAccess, .systemSettings, .featureFlagOverride:
                return .admin
            }
        }
        
        /// Category for grouping in UI
        var category: FeatureCategory {
            switch self {
            case .viewEvents, .viewMusic, .viewMerch, .viewNews, .socialCapitalView:
                return .community
            case .volunteerShifts, .volunteerTasks, .eventCheckIn, .volunteerChat:
                return .volunteering
            case .campShifts, .campTasks, .campLayout, .campRoster, .campChat,
                 .playaMap, .draftParticipation, .safetyFeatures:
                return .camp
            case .memberManagement, .shiftCreation, .taskCreation, .announcements,
                 .campSettings, .viewReports:
                return .leadership
            case .roleSwitcher, .allCampAccess, .systemSettings, .featureFlagOverride:
                return .admin
            }
        }
    }
    
    enum FeatureCategory: String, CaseIterable {
        case community = "Community"
        case volunteering = "Volunteering"
        case camp = "Camp"
        case leadership = "Leadership"
        case admin = "Admin"
        
        var icon: String {
            switch self {
            case .community: return "heart.fill"
            case .volunteering: return "hands.sparkles.fill"
            case .camp: return "tent.fill"
            case .leadership: return "star.fill"
            case .admin: return "gearshape.fill"
            }
        }
        
        var features: [Feature] {
            Feature.allCases.filter { $0.category == self }
        }
    }
    
    // MARK: - Check Feature Access
    
    /// Check if a feature is enabled for a given role
    static func isEnabled(_ feature: Feature, for role: UserRole) -> Bool {
        role.hasPermission(of: feature.minimumRole)
    }
    
    /// Get all features available for a role
    static func availableFeatures(for role: UserRole) -> [Feature] {
        Feature.allCases.filter { isEnabled($0, for: role) }
    }
    
    /// Get features by category for a role
    static func featuresByCategory(for role: UserRole) -> [FeatureCategory: [Feature]] {
        var result: [FeatureCategory: [Feature]] = [:]
        for category in FeatureCategory.allCases {
            let features = category.features.filter { isEnabled($0, for: role) }
            if !features.isEmpty {
                result[category] = features
            }
        }
        return result
    }
}

// MARK: - Event Types
/// Different types of events the community participates in.
/// Each event type may have different features enabled.

enum EventType: String, Codable, CaseIterable, Identifiable {
    case burningMan = "Burning Man"
    case regionalBurn = "Regional Burn"
    case residency = "Residency"
    case artBasel = "Art Basel"
    case clubEvent = "Club Event"
    case campTrip = "Camp Trip"
    case buildWeek = "Build Week"
    case fundraiser = "Fundraiser"
    case workshop = "Workshop"
    case other = "Other"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .burningMan: return "flame.fill"
        case .regionalBurn: return "sun.max.fill"
        case .residency: return "house.fill"
        case .artBasel: return "paintpalette.fill"
        case .clubEvent: return "music.note.house.fill"
        case .campTrip: return "tent.fill"
        case .buildWeek: return "hammer.fill"
        case .fundraiser: return "heart.fill"
        case .workshop: return "lightbulb.fill"
        case .other: return "star.fill"
        }
    }
    
    var description: String {
        switch self {
        case .burningMan: return "The big burn in Black Rock City"
        case .regionalBurn: return "Regional Burning Man events"
        case .residency: return "Robot Heart Residency (Bay Area)"
        case .artBasel: return "Miami Art Basel events"
        case .clubEvent: return "Club nights and parties"
        case .campTrip: return "Off-season camping trips"
        case .buildWeek: return "Pre-event build and prep"
        case .fundraiser: return "Foundation fundraising events"
        case .workshop: return "DJ, lighting, or art workshops"
        case .other: return "Other community gatherings"
        }
    }
    
    /// Whether this event type supports camp layout planning
    var supportsCampLayout: Bool {
        switch self {
        case .burningMan, .regionalBurn, .campTrip:
            return true
        default:
            return false
        }
    }
    
    /// Whether this event type has shifts
    var hasShifts: Bool {
        switch self {
        case .burningMan, .regionalBurn, .residency, .artBasel, .buildWeek:
            return true
        default:
            return false
        }
    }
    
    /// Whether this event uses the playa map
    var hasPlayaMap: Bool {
        switch self {
        case .burningMan, .regionalBurn:
            return true
        default:
            return false
        }
    }
}

// MARK: - Community (replaces Camp for broader use)
/// A community is a group of people who participate in events together.
/// "Camp" is one type of community structure, but the concept is broader.

struct Community: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var type: CommunityType
    var location: String  // Home base (e.g., "New York City", "Bay Area")
    var memberCount: Int
    var foundedYear: Int?
    var socialLinks: SocialLinks?
    var isVerified: Bool
    var createdAt: Date
    var updatedAt: Date
    
    enum CommunityType: String, Codable, CaseIterable {
        case camp = "Camp"
        case collective = "Collective"
        case foundation = "Foundation"
        case artCar = "Art Car"
        case soundCamp = "Sound Camp"
        case themeCamp = "Theme Camp"
        
        var icon: String {
            switch self {
            case .camp: return "tent.fill"
            case .collective: return "person.3.fill"
            case .foundation: return "building.columns.fill"
            case .artCar: return "car.fill"
            case .soundCamp: return "speaker.wave.3.fill"
            case .themeCamp: return "theatermasks.fill"
            }
        }
    }
    
    struct SocialLinks: Codable {
        var website: String?
        var instagram: String?
        var soundcloud: String?
        var youtube: String?
        var facebook: String?
    }
    
    init(name: String, type: CommunityType, location: String) {
        self.id = UUID()
        self.name = name
        self.description = ""
        self.type = type
        self.location = location
        self.memberCount = 0
        self.isVerified = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Membership
/// Represents a user's membership in a community with their role.

struct Membership: Identifiable, Codable {
    let id: UUID
    let userID: String
    let communityID: UUID
    var role: UserRole
    var joinedAt: Date
    var status: MembershipStatus
    var invitedBy: String?
    
    enum MembershipStatus: String, Codable {
        case pending = "Pending"
        case active = "Active"
        case inactive = "Inactive"
        case suspended = "Suspended"
    }
    
    init(userID: String, communityID: UUID, role: UserRole) {
        self.id = UUID()
        self.userID = userID
        self.communityID = communityID
        self.role = role
        self.joinedAt = Date()
        self.status = .pending
    }
}
