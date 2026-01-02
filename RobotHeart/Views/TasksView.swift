import SwiftUI

// MARK: - Tasks Hub View
struct TasksHubView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedArea: TaskArea?
    @State private var showingAddTask = false
    @State private var showingAddArea = false
    @State private var showCompleted = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Stats header
                    TaskStatsHeader()
                    
                    // Area tabs
                    AreaTabsView(selectedArea: $selectedArea)
                    
                    // Task list
                    TaskListView(
                        selectedArea: selectedArea,
                        showCompleted: showCompleted
                    )
                }
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("Show Completed", isOn: $showCompleted)
                        
                        Divider()
                        
                        Button(action: { showingAddArea = true }) {
                            Label("Add Area", systemImage: "folder.badge.plus")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.Colors.sunsetOrange)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(preselectedArea: selectedArea)
            }
            .sheet(isPresented: $showingAddArea) {
                AddAreaView()
            }
        }
    }
}

// MARK: - Task Stats Header
struct TaskStatsHeader: View {
    @EnvironmentObject var taskManager: TaskManager
    
    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            TaskStatPill(
                value: "\(taskManager.openTasksCount)",
                label: "Open",
                color: Theme.Colors.turquoise
            )
            
            TaskStatPill(
                value: "\(taskManager.highPriorityCount)",
                label: "Critical",
                color: Theme.Colors.emergency
            )
            
            TaskStatPill(
                value: "\(taskManager.myTasks.count)",
                label: "Mine",
                color: Theme.Colors.sunsetOrange
            )
            
            TaskStatPill(
                value: "\(taskManager.myTotalPoints)",
                label: "Points",
                color: Theme.Colors.goldenYellow
            )
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Task Stat Pill
struct TaskStatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Area Tabs View
struct AreaTabsView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Binding var selectedArea: TaskArea?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                // All tasks
                AreaTab(
                    name: "All",
                    icon: "tray.full.fill",
                    color: Theme.Colors.robotCream,
                    count: taskManager.openTasksCount,
                    isSelected: selectedArea == nil
                ) {
                    selectedArea = nil
                }
                
                // Each area
                ForEach(taskManager.areas) { area in
                    AreaTab(
                        name: area.name,
                        icon: area.icon,
                        color: area.swiftUIColor,
                        count: taskManager.tasksInArea(area.id).count,
                        isSelected: selectedArea?.id == area.id
                    ) {
                        selectedArea = area
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.backgroundDark)
    }
}

// MARK: - Area Tab
struct AreaTab: View {
    let name: String
    let icon: String
    let color: Color
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption)
                Text(name)
                    .font(Theme.Typography.caption)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isSelected ? color : Theme.Colors.backgroundDark)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Theme.Colors.backgroundDark : color)
                        .cornerRadius(Theme.CornerRadius.full)
                }
            }
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : color)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(isSelected ? color : Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Task List View
struct TaskListView: View {
    @EnvironmentObject var taskManager: TaskManager
    let selectedArea: TaskArea?
    let showCompleted: Bool
    
    var tasks: [AdHocTask] {
        var result = taskManager.tasks
        
        if let area = selectedArea {
            result = result.filter { $0.areaID == area.id }
        }
        
        if !showCompleted {
            result = result.filter { $0.status != .completed }
        }
        
        // Sort by priority then date
        return result.sorted { t1, t2 in
            if t1.status == .completed && t2.status != .completed { return false }
            if t1.status != .completed && t2.status == .completed { return true }
            if t1.priority != t2.priority { return t1.priority < t2.priority }
            return t1.createdAt > t2.createdAt
        }
    }
    
    var body: some View {
        if tasks.isEmpty {
            EmptyTasksView(areaName: selectedArea?.name)
        } else {
            ScrollView {
                LazyVStack(spacing: Theme.Spacing.sm) {
                    // Overdue section
                    let overdue = tasks.filter { $0.isOverdue }
                    if !overdue.isEmpty {
                        TaskSection(title: "⚠️ Overdue", tasks: overdue)
                    }
                    
                    // P1 Critical
                    let p1 = tasks.filter { $0.priority == .high && !$0.isOverdue && $0.status != .completed }
                    if !p1.isEmpty {
                        TaskSection(title: "🔴 Critical (P1)", tasks: p1)
                    }
                    
                    // P2 Important
                    let p2 = tasks.filter { $0.priority == .medium && !$0.isOverdue && $0.status != .completed }
                    if !p2.isEmpty {
                        TaskSection(title: "🟡 Important (P2)", tasks: p2)
                    }
                    
                    // P3 Normal
                    let p3 = tasks.filter { $0.priority == .low && !$0.isOverdue && $0.status != .completed }
                    if !p3.isEmpty {
                        TaskSection(title: "🟢 Normal (P3)", tasks: p3)
                    }
                    
                    // Completed
                    if showCompleted {
                        let completed = tasks.filter { $0.status == .completed }
                        if !completed.isEmpty {
                            TaskSection(title: "✅ Completed", tasks: completed)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Task Section
struct TaskSection: View {
    let title: String
    let tasks: [AdHocTask]
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                .padding(.leading, Theme.Spacing.xs)
            
            ForEach(tasks) { task in
                TaskCard(task: task)
            }
        }
    }
}

// MARK: - Task Card
struct TaskCard: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var profileManager: ProfileManager
    let task: AdHocTask
    
    @State private var showingDetail = false
    
    var area: TaskArea? {
        taskManager.area(for: task.areaID)
    }
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: Theme.Spacing.md) {
                // Status/Complete button
                Button(action: toggleComplete) {
                    Image(systemName: task.status.icon)
                        .font(.title2)
                        .foregroundColor(task.status.color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    HStack {
                        Text(task.title)
                            .font(Theme.Typography.body)
                            .foregroundColor(task.status == .completed ? Theme.Colors.robotCream.opacity(0.5) : Theme.Colors.robotCream)
                            .strikethrough(task.status == .completed)
                            .lineLimit(1)
                        
                        if task.isOverdue {
                            Image(systemName: "clock.badge.exclamationmark.fill")
                                .font(.caption)
                                .foregroundColor(Theme.Colors.emergency)
                        }
                    }
                    
                    // Meta info
                    HStack(spacing: Theme.Spacing.sm) {
                        // Area
                        if let area = area {
                            HStack(spacing: 2) {
                                Image(systemName: area.icon)
                                Text(area.name)
                            }
                            .font(Theme.Typography.footnote)
                            .foregroundColor(area.swiftUIColor)
                        }
                        
                        // Assigned
                        if let assignee = task.assignedToName {
                            HStack(spacing: 2) {
                                Image(systemName: "person.fill")
                                Text(assignee)
                            }
                            .font(Theme.Typography.footnote)
                            .foregroundColor(Theme.Colors.turquoise)
                        }
                        
                        // Due date
                        if let due = task.dueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                Text(due, style: .date)
                            }
                            .font(Theme.Typography.footnote)
                            .foregroundColor(task.isOverdue ? Theme.Colors.emergency : Theme.Colors.robotCream.opacity(0.5))
                        }
                    }
                }
                
                Spacer()
                
                // Priority badge
                Text(task.priority.shortLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(task.priority.color)
                    .cornerRadius(Theme.CornerRadius.sm)
                
                // Points
                Text("+\(task.pointsValue)")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.goldenYellow)
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            TaskDetailView(task: task)
        }
    }
    
    private func toggleComplete() {
        if task.status == .completed {
            taskManager.reopenTask(task.id)
        } else {
            _ = taskManager.completeTask(task.id, completedByName: profileManager.myProfile.displayName)
        }
    }
}

// MARK: - Empty Tasks View
struct EmptyTasksView: View {
    let areaName: String?
    
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.connected.opacity(0.5))
            
            Text(areaName != nil ? "No tasks in \(areaName!)" : "All caught up!")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Tap + to add a new task")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            
            Spacer()
        }
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    var preselectedArea: TaskArea?
    
    @State private var title = ""
    @State private var description = ""
    @State private var selectedAreaID: UUID?
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Task title", text: $title)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        TextField("Description (optional)", text: $description, axis: .vertical)
                            .foregroundColor(Theme.Colors.robotCream)
                            .lineLimit(3...6)
                    } header: {
                        Text("Task")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        Picker("Area", selection: $selectedAreaID) {
                            Text("Select Area").tag(nil as UUID?)
                            ForEach(taskManager.areas) { area in
                                Label(area.name, systemImage: area.icon)
                                    .tag(area.id as UUID?)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        Picker("Priority", selection: $priority) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in
                                HStack {
                                    Text(p.label)
                                    Text("+\(p.points) pts")
                                        .foregroundColor(Theme.Colors.goldenYellow)
                                }
                                .tag(p)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Details")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        Toggle("Set Due Date", isOn: $hasDueDate)
                            .foregroundColor(Theme.Colors.robotCream)
                            .tint(Theme.Colors.sunsetOrange)
                        
                        if hasDueDate {
                            DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                    } header: {
                        Text("Due Date")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Points preview
                    Section {
                        HStack {
                            Text("Points for completion")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            Text("+\(priority.points)")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.goldenYellow)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createTask()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(title.isEmpty || selectedAreaID == nil)
                }
            }
            .onAppear {
                if let area = preselectedArea {
                    selectedAreaID = area.id
                }
            }
        }
    }
    
    private func createTask() {
        guard let areaID = selectedAreaID else { return }
        
        _ = taskManager.createTask(
            title: title,
            description: description.isEmpty ? nil : description,
            areaID: areaID,
            priority: priority,
            createdByName: profileManager.myProfile.displayName,
            dueDate: hasDueDate ? dueDate : nil
        )
        
        dismiss()
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    @EnvironmentObject var taskManager: TaskManager
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    let task: AdHocTask
    
    @State private var showingEdit = false
    
    var area: TaskArea? {
        taskManager.area(for: task.areaID)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        // Header
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack {
                                if let area = area {
                                    HStack(spacing: 4) {
                                        Image(systemName: area.icon)
                                        Text(area.name)
                                    }
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(area.swiftUIColor)
                                }
                                
                                Spacer()
                                
                                Text(task.priority.label)
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, Theme.Spacing.sm)
                                    .padding(.vertical, 4)
                                    .background(task.priority.color)
                                    .cornerRadius(Theme.CornerRadius.sm)
                            }
                            
                            Text(task.title)
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            if let desc = task.description {
                                Text(desc)
                                    .font(Theme.Typography.body)
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.md)
                        
                        // Status & Info
                        VStack(spacing: Theme.Spacing.sm) {
                            DetailRow(label: "Status", value: task.status.rawValue, icon: task.status.icon, color: task.status.color)
                            
                            DetailRow(label: "Points", value: "+\(task.pointsValue)", icon: "star.fill", color: Theme.Colors.goldenYellow)
                            
                            if let assignee = task.assignedToName {
                                DetailRow(label: "Assigned To", value: assignee, icon: "person.fill", color: Theme.Colors.turquoise)
                            }
                            
                            if let due = task.dueDate {
                                DetailRow(
                                    label: "Due",
                                    value: due.formatted(date: .abbreviated, time: .shortened),
                                    icon: "calendar",
                                    color: task.isOverdue ? Theme.Colors.emergency : Theme.Colors.robotCream
                                )
                            }
                            
                            DetailRow(label: "Created By", value: task.createdByName, icon: "person.badge.plus", color: Theme.Colors.robotCream.opacity(0.6))
                            
                            DetailRow(label: "Created", value: task.createdAt.formatted(date: .abbreviated, time: .shortened), icon: "clock", color: Theme.Colors.robotCream.opacity(0.6))
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.md)
                        
                        // Actions
                        VStack(spacing: Theme.Spacing.sm) {
                            if task.status != .completed {
                                // Claim/Assign
                                if task.assignedTo == nil {
                                    Button(action: claimTask) {
                                        TaskActionButton(title: "Claim This Task", icon: "hand.raised.fill", color: Theme.Colors.turquoise)
                                    }
                                }
                                
                                // Complete
                                Button(action: completeTask) {
                                    TaskActionButton(title: "Mark Complete", icon: "checkmark.circle.fill", color: Theme.Colors.connected)
                                }
                                
                                // Change priority
                                Menu {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Button(action: { taskManager.setPriority(task.id, priority: p) }) {
                                            Label(p.label, systemImage: p.icon)
                                        }
                                    }
                                } label: {
                                    TaskActionButton(title: "Change Priority", icon: "arrow.up.arrow.down", color: Theme.Colors.warning)
                                }
                            } else {
                                // Reopen
                                Button(action: reopenTask) {
                                    TaskActionButton(title: "Reopen Task", icon: "arrow.uturn.backward", color: Theme.Colors.warning)
                                }
                            }
                            
                            // Delete
                            Button(action: deleteTask) {
                                TaskActionButton(title: "Delete Task", icon: "trash.fill", color: Theme.Colors.disconnected)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    private func claimTask() {
        taskManager.claimTask(task.id, memberName: profileManager.myProfile.displayName)
        dismiss()
    }
    
    private func completeTask() {
        _ = taskManager.completeTask(task.id, completedByName: profileManager.myProfile.displayName)
        dismiss()
    }
    
    private func reopenTask() {
        taskManager.reopenTask(task.id)
        dismiss()
    }
    
    private func deleteTask() {
        taskManager.deleteTask(task.id)
        dismiss()
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
        }
    }
}

// MARK: - Task Action Button
struct TaskActionButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title)
        }
        .font(Theme.Typography.callout)
        .foregroundColor(color)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Add Area View
struct AddAreaView: View {
    @EnvironmentObject var taskManager: TaskManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = "4ECDC4"
    
    let icons = ["folder.fill", "bus.fill", "tent.fill", "sun.max.fill", "fork.knife", "wrench.fill", "music.note", "bolt.fill", "drop.fill", "leaf.fill", "star.fill", "heart.fill"]
    let colors = ["D84315", "4ECDC4", "FFB300", "FF8B94", "E91E63", "4CAF50", "9C27B0", "2196F3"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Area Name", text: $name)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Name")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: Theme.Spacing.md) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundColor(selectedIcon == icon ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
                                        .frame(width: 44, height: 44)
                                        .background(selectedIcon == icon ? Theme.Colors.backgroundLight : Color.clear)
                                        .cornerRadius(Theme.CornerRadius.sm)
                                }
                            }
                        }
                    } header: {
                        Text("Icon")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Theme.Spacing.md) {
                            ForEach(colors, id: \.self) { color in
                                Button(action: { selectedColor = color }) {
                                    Circle()
                                        .fill(Color(hex: color))
                                        .frame(width: 44, height: 44)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color ? Color.white : Color.clear, lineWidth: 3)
                                        )
                                }
                            }
                        }
                    } header: {
                        Text("Color")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Preview
                    Section {
                        HStack {
                            Image(systemName: selectedIcon)
                                .foregroundColor(Color(hex: selectedColor))
                            Text(name.isEmpty ? "Area Name" : name)
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                        .padding()
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.md)
                    } header: {
                        Text("Preview")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        _ = taskManager.addArea(name: name, icon: selectedIcon, color: selectedColor)
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    TasksHubView()
        .environmentObject(TaskManager())
        .environmentObject(ProfileManager())
}
