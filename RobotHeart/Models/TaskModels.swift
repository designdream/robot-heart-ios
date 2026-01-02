import Foundation
import SwiftUI

// MARK: - Task Area (Topic/Location)
struct TaskArea: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: String
    var color: String  // Hex color
    var sortOrder: Int
    
    init(id: UUID = UUID(), name: String, icon: String, color: String, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
    }
    
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    // Default areas
    static let bus = TaskArea(name: "Bus", icon: "bus.fill", color: "D84315", sortOrder: 0)
    static let camp = TaskArea(name: "Camp", icon: "tent.fill", color: "4ECDC4", sortOrder: 1)
    static let shady = TaskArea(name: "Shady", icon: "sun.max.fill", color: "FFB300", sortOrder: 2)
    static let kitchen = TaskArea(name: "Kitchen", icon: "fork.knife", color: "FF8B94", sortOrder: 3)
    static let general = TaskArea(name: "General", icon: "star.fill", color: "E8DCC8", sortOrder: 4)
    
    static let defaults: [TaskArea] = [bus, camp, shady, kitchen, general]
}

// MARK: - Task Priority
enum TaskPriority: Int, Codable, CaseIterable, Comparable {
    case high = 1      // P1 - Urgent/Critical
    case medium = 2    // P2 - Important
    case low = 3       // P3 - Nice to have
    
    var label: String {
        switch self {
        case .high: return "P1 - Critical"
        case .medium: return "P2 - Important"
        case .low: return "P3 - Normal"
        }
    }
    
    var shortLabel: String {
        switch self {
        case .high: return "P1"
        case .medium: return "P2"
        case .low: return "P3"
        }
    }
    
    var color: Color {
        switch self {
        case .high: return Theme.Colors.emergency
        case .medium: return Theme.Colors.warning
        case .low: return Theme.Colors.turquoise
        }
    }
    
    var points: Int {
        switch self {
        case .high: return 15    // Critical tasks worth more
        case .medium: return 10
        case .low: return 5
        }
    }
    
    var icon: String {
        switch self {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        }
    }
    
    static func < (lhs: TaskPriority, rhs: TaskPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Task Status
enum TaskStatus: String, Codable, CaseIterable {
    case open = "Open"
    case inProgress = "In Progress"
    case completed = "Completed"
    case blocked = "Blocked"
    
    var icon: String {
        switch self {
        case .open: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .blocked: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .open: return Theme.Colors.robotCream.opacity(0.5)
        case .inProgress: return Theme.Colors.turquoise
        case .completed: return Theme.Colors.connected
        case .blocked: return Theme.Colors.disconnected
        }
    }
}

// MARK: - Ad-Hoc Task
struct AdHocTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var areaID: UUID
    var priority: TaskPriority
    var status: TaskStatus
    var assignedTo: String?        // Member ID
    var assignedToName: String?
    var createdBy: String
    var createdByName: String
    var completedBy: String?
    var completedByName: String?
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var notes: String?
    
    init(
        title: String,
        description: String? = nil,
        areaID: UUID,
        priority: TaskPriority = .medium,
        createdBy: String,
        createdByName: String,
        dueDate: Date? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.areaID = areaID
        self.priority = priority
        self.status = .open
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.dueDate = dueDate
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var isOverdue: Bool {
        guard let due = dueDate, status != .completed else { return false }
        return due < Date()
    }
    
    var pointsValue: Int {
        priority.points
    }
}

// MARK: - Task Completion Record (for points)
struct TaskCompletion: Identifiable, Codable {
    let id: UUID
    let taskID: UUID
    let taskTitle: String
    let areaName: String
    let priority: TaskPriority
    let completedBy: String
    let completedByName: String
    let pointsAwarded: Int
    let completedAt: Date
    
    init(task: AdHocTask, areaName: String, completedBy: String, completedByName: String) {
        self.id = UUID()
        self.taskID = task.id
        self.taskTitle = task.title
        self.areaName = areaName
        self.priority = task.priority
        self.completedBy = completedBy
        self.completedByName = completedByName
        self.pointsAwarded = task.pointsValue
        self.completedAt = Date()
    }
}

// MARK: - Task Filter
struct TaskFilter {
    var areaID: UUID?
    var priority: TaskPriority?
    var status: TaskStatus?
    var assignedTo: String?
    var showCompleted: Bool = false
    
    var isActive: Bool {
        areaID != nil || priority != nil || status != nil || assignedTo != nil
    }
}
