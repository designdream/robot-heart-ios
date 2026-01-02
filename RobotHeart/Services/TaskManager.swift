import Foundation
import Combine

class TaskManager: ObservableObject {
    // MARK: - Published Properties
    @Published var tasks: [AdHocTask] = []
    @Published var areas: [TaskArea] = []
    @Published var completions: [TaskCompletion] = []
    @Published var filter: TaskFilter = TaskFilter()
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let tasksKey = "adHocTasks"
    private let areasKey = "taskAreas"
    private let completionsKey = "taskCompletions"
    private let currentUserID = "!local"
    
    // MARK: - Computed Properties
    var filteredTasks: [AdHocTask] {
        var result = tasks
        
        if let areaID = filter.areaID {
            result = result.filter { $0.areaID == areaID }
        }
        
        if let priority = filter.priority {
            result = result.filter { $0.priority == priority }
        }
        
        if let status = filter.status {
            result = result.filter { $0.status == status }
        }
        
        if let assignedTo = filter.assignedTo {
            result = result.filter { $0.assignedTo == assignedTo }
        }
        
        if !filter.showCompleted {
            result = result.filter { $0.status != .completed }
        }
        
        // Sort by priority (high first), then by due date, then by creation
        return result.sorted { task1, task2 in
            if task1.priority != task2.priority {
                return task1.priority < task2.priority
            }
            if let due1 = task1.dueDate, let due2 = task2.dueDate {
                return due1 < due2
            }
            if task1.dueDate != nil { return true }
            if task2.dueDate != nil { return false }
            return task1.createdAt > task2.createdAt
        }
    }
    
    var openTasksCount: Int {
        tasks.filter { $0.status == .open || $0.status == .inProgress }.count
    }
    
    var highPriorityCount: Int {
        tasks.filter { $0.priority == .high && $0.status != .completed }.count
    }
    
    var myTasks: [AdHocTask] {
        tasks.filter { $0.assignedTo == currentUserID && $0.status != .completed }
    }
    
    var overdueTasks: [AdHocTask] {
        tasks.filter { $0.isOverdue }
    }
    
    // MARK: - Initialization
    init() {
        loadAreas()
        loadTasks()
        loadCompletions()
        
        // Seed default areas if empty
        if areas.isEmpty {
            areas = TaskArea.defaults
            saveAreas()
        }
    }
    
    // MARK: - Area Management
    func addArea(name: String, icon: String, color: String) -> TaskArea {
        let area = TaskArea(
            name: name,
            icon: icon,
            color: color,
            sortOrder: areas.count
        )
        areas.append(area)
        saveAreas()
        return area
    }
    
    func updateArea(_ areaID: UUID, name: String? = nil, icon: String? = nil, color: String? = nil) {
        guard let index = areas.firstIndex(where: { $0.id == areaID }) else { return }
        
        if let name = name { areas[index].name = name }
        if let icon = icon { areas[index].icon = icon }
        if let color = color { areas[index].color = color }
        
        saveAreas()
    }
    
    func deleteArea(_ areaID: UUID) {
        // Don't delete if tasks exist in this area
        guard !tasks.contains(where: { $0.areaID == areaID }) else { return }
        areas.removeAll { $0.id == areaID }
        saveAreas()
    }
    
    func area(for id: UUID) -> TaskArea? {
        areas.first { $0.id == id }
    }
    
    func tasksInArea(_ areaID: UUID) -> [AdHocTask] {
        tasks.filter { $0.areaID == areaID && $0.status != .completed }
    }
    
    // MARK: - Task Management
    func createTask(
        title: String,
        description: String? = nil,
        areaID: UUID,
        priority: TaskPriority = .medium,
        createdByName: String,
        dueDate: Date? = nil
    ) -> AdHocTask {
        let task = AdHocTask(
            title: title,
            description: description,
            areaID: areaID,
            priority: priority,
            createdBy: currentUserID,
            createdByName: createdByName,
            dueDate: dueDate
        )
        tasks.append(task)
        saveTasks()
        
        NotificationCenter.default.post(name: .taskCreated, object: task)
        return task
    }
    
    func updateTask(_ taskID: UUID, updates: (inout AdHocTask) -> Void) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        updates(&tasks[index])
        tasks[index].updatedAt = Date()
        saveTasks()
    }
    
    func deleteTask(_ taskID: UUID) {
        tasks.removeAll { $0.id == taskID }
        saveTasks()
    }
    
    func assignTask(_ taskID: UUID, to memberID: String, memberName: String) {
        updateTask(taskID) { task in
            task.assignedTo = memberID
            task.assignedToName = memberName
            if task.status == .open {
                task.status = .inProgress
            }
        }
    }
    
    func unassignTask(_ taskID: UUID) {
        updateTask(taskID) { task in
            task.assignedTo = nil
            task.assignedToName = nil
        }
    }
    
    func claimTask(_ taskID: UUID, memberName: String) {
        assignTask(taskID, to: currentUserID, memberName: memberName)
    }
    
    func setStatus(_ taskID: UUID, status: TaskStatus) {
        updateTask(taskID) { task in
            task.status = status
        }
    }
    
    func setPriority(_ taskID: UUID, priority: TaskPriority) {
        updateTask(taskID) { task in
            task.priority = priority
        }
    }
    
    // MARK: - Task Completion
    func completeTask(_ taskID: UUID, completedByName: String) -> TaskCompletion? {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return nil }
        guard let area = area(for: tasks[index].areaID) else { return nil }
        
        // Update task
        tasks[index].status = .completed
        tasks[index].completedBy = currentUserID
        tasks[index].completedByName = completedByName
        tasks[index].completedAt = Date()
        tasks[index].updatedAt = Date()
        
        // Create completion record
        let completion = TaskCompletion(
            task: tasks[index],
            areaName: area.name,
            completedBy: currentUserID,
            completedByName: completedByName
        )
        completions.append(completion)
        
        saveTasks()
        saveCompletions()
        
        // Notify for points
        NotificationCenter.default.post(name: .taskCompleted, object: completion)
        
        return completion
    }
    
    func reopenTask(_ taskID: UUID) {
        updateTask(taskID) { task in
            task.status = .open
            task.completedBy = nil
            task.completedByName = nil
            task.completedAt = nil
        }
        
        // Remove completion record
        completions.removeAll { $0.taskID == taskID }
        saveCompletions()
    }
    
    // MARK: - Statistics
    func completionsForMember(_ memberID: String) -> [TaskCompletion] {
        completions.filter { $0.completedBy == memberID }
    }
    
    func totalPointsForMember(_ memberID: String) -> Int {
        completionsForMember(memberID).reduce(0) { $0 + $1.pointsAwarded }
    }
    
    var myCompletions: [TaskCompletion] {
        completionsForMember(currentUserID)
    }
    
    var myTotalPoints: Int {
        totalPointsForMember(currentUserID)
    }
    
    func tasksByArea() -> [(area: TaskArea, count: Int)] {
        areas.map { area in
            (area: area, count: tasksInArea(area.id).count)
        }.sorted { $0.area.sortOrder < $1.area.sortOrder }
    }
    
    // MARK: - Persistence
    private func loadTasks() {
        if let data = userDefaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([AdHocTask].self, from: data) {
            tasks = decoded
        }
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            userDefaults.set(encoded, forKey: tasksKey)
        }
    }
    
    private func loadAreas() {
        if let data = userDefaults.data(forKey: areasKey),
           let decoded = try? JSONDecoder().decode([TaskArea].self, from: data) {
            areas = decoded
        }
    }
    
    private func saveAreas() {
        if let encoded = try? JSONEncoder().encode(areas) {
            userDefaults.set(encoded, forKey: areasKey)
        }
    }
    
    private func loadCompletions() {
        if let data = userDefaults.data(forKey: completionsKey),
           let decoded = try? JSONDecoder().decode([TaskCompletion].self, from: data) {
            completions = decoded
        }
    }
    
    private func saveCompletions() {
        if let encoded = try? JSONEncoder().encode(completions) {
            userDefaults.set(encoded, forKey: completionsKey)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let taskCreated = Notification.Name("taskCreated")
    static let taskCompleted = Notification.Name("taskCompleted")
}
