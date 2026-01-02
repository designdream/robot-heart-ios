import Foundation
import Combine
import SwiftUI

class CampLayoutManager: ObservableObject {
    // MARK: - Published Properties
    @Published var currentLayout: CampLayout?
    @Published var savedLayouts: [CampLayout] = []
    @Published var selectedItem: PlaceableItem?
    @Published var selectedLane: CampLane?
    @Published var isDragging: Bool = false
    @Published var showGrid: Bool = true
    @Published var snapToGrid: Bool = true
    @Published var zoomLevel: CGFloat = 1.0
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let layoutsKey = "campLayouts"
    private let currentLayoutKey = "currentCampLayout"
    
    // MARK: - Computed Properties
    var hasLayout: Bool {
        currentLayout != nil
    }
    
    var validationErrors: [String] {
        guard let layout = currentLayout else { return [] }
        var errors: [String] = []
        
        // Fire lane requirement check
        if layout.requiresFireLaneButMissing {
            errors.append("⚠️ Fire Lane Required: Camps larger than 100'×100' must have a 20' fire lane (per Burning Man)")
        }
        
        let outOfBounds = layout.itemsOutOfBounds()
        for item in outOfBounds {
            errors.append("\(item.name) is outside the camp boundary")
        }
        
        let overlaps = layout.overlappingItems()
        for (item1, item2) in overlaps {
            errors.append("\(item1.name) overlaps with \(item2.name)")
        }
        
        return errors
    }
    
    var isValid: Bool {
        validationErrors.isEmpty
    }
    
    // MARK: - Initialization
    init() {
        loadLayouts()
        loadCurrentLayout()
    }
    
    // MARK: - Layout Management
    func createLayout(widthFeet: Double, depthFeet: Double, name: String, gridUnit: Double = 5) {
        let grid = CampGrid(widthFeet: widthFeet, depthFeet: depthFeet, gridUnitFeet: gridUnit, name: name)
        currentLayout = CampLayout(grid: grid)
        saveCurrentLayout()
    }
    
    func saveLayout() {
        guard var layout = currentLayout else { return }
        layout.grid.updatedAt = Date()
        
        // Update or add to saved layouts
        if let index = savedLayouts.firstIndex(where: { $0.id == layout.id }) {
            savedLayouts[index] = layout
        } else {
            savedLayouts.append(layout)
        }
        
        currentLayout = layout
        saveLayouts()
        saveCurrentLayout()
    }
    
    func loadLayout(_ layout: CampLayout) {
        currentLayout = layout
        saveCurrentLayout()
    }
    
    func deleteLayout(_ layoutID: UUID) {
        savedLayouts.removeAll { $0.id == layoutID }
        if currentLayout?.id == layoutID {
            currentLayout = nil
        }
        saveLayouts()
        saveCurrentLayout()
    }
    
    func duplicateLayout(_ layout: CampLayout, newName: String) -> CampLayout {
        var newLayout = CampLayout(grid: layout.grid)
        newLayout.grid.name = newName
        newLayout.items = layout.items.map { item in
            var newItem = item
            // Generate new IDs
            return PlaceableItem(
                type: item.type,
                name: item.name,
                widthFeet: item.widthFeet,
                depthFeet: item.depthFeet,
                xPosition: item.xPosition,
                yPosition: item.yPosition,
                rotation: item.rotation
            )
        }
        newLayout.lanes = layout.lanes
        newLayout.notes = layout.notes
        
        savedLayouts.append(newLayout)
        saveLayouts()
        return newLayout
    }
    
    // MARK: - Item Management
    func addItem(_ item: PlaceableItem) {
        guard currentLayout != nil else { return }
        currentLayout?.items.append(item)
        saveCurrentLayout()
    }
    
    func addItem(type: PlaceableItem.ItemType, name: String, width: Double, depth: Double, x: Double? = nil, y: Double? = nil) {
        guard let grid = currentLayout?.grid else { return }
        
        // Default to center of canvas if no position specified
        var xPos = x ?? (grid.widthFeet / 2 - width / 2)
        var yPos = y ?? (grid.depthFeet / 2 - depth / 2)
        
        // Snap to grid if enabled
        if snapToGrid {
            xPos = snapToGridUnit(xPos, unit: grid.gridUnitFeet)
            yPos = snapToGridUnit(yPos, unit: grid.gridUnitFeet)
        }
        
        // Clamp to bounds
        xPos = max(0, min(xPos, grid.widthFeet - width))
        yPos = max(0, min(yPos, grid.depthFeet - depth))
        
        let item = PlaceableItem(type: type, name: name, widthFeet: width, depthFeet: depth, xPosition: xPos, yPosition: yPos)
        addItem(item)
    }
    
    func updateItem(_ itemID: UUID, updates: (inout PlaceableItem) -> Void) {
        guard let index = currentLayout?.items.firstIndex(where: { $0.id == itemID }) else { return }
        updates(&currentLayout!.items[index])
        saveCurrentLayout()
    }
    
    func moveItem(_ itemID: UUID, to position: CGPoint) {
        guard let grid = currentLayout?.grid else { return }
        
        var x = Double(position.x)
        var y = Double(position.y)
        
        // Snap to grid
        if snapToGrid {
            x = snapToGridUnit(x, unit: grid.gridUnitFeet)
            y = snapToGridUnit(y, unit: grid.gridUnitFeet)
        }
        
        // Clamp to bounds
        if let item = currentLayout?.items.first(where: { $0.id == itemID }) {
            x = max(0, min(x, grid.widthFeet - item.effectiveWidth))
            y = max(0, min(y, grid.depthFeet - item.effectiveDepth))
        }
        
        updateItem(itemID) { item in
            item.xPosition = x
            item.yPosition = y
        }
    }
    
    func rotateItem(_ itemID: UUID) {
        updateItem(itemID) { item in
            item.rotation = (item.rotation + 90).truncatingRemainder(dividingBy: 360)
        }
    }
    
    func deleteItem(_ itemID: UUID) {
        currentLayout?.items.removeAll { $0.id == itemID }
        if selectedItem?.id == itemID {
            selectedItem = nil
        }
        saveCurrentLayout()
    }
    
    func assignItemToMember(_ itemID: UUID, memberID: String, memberName: String) {
        updateItem(itemID) { item in
            item.assignedTo = memberID
            item.assignedName = memberName
        }
    }
    
    // MARK: - Lane Management
    func addLane(_ lane: CampLane) {
        currentLayout?.lanes.append(lane)
        saveCurrentLayout()
    }
    
    func addLane(type: CampLane.LaneType, name: String, startX: Double, startY: Double, endX: Double, endY: Double) {
        let lane = CampLane(type: type, name: name, startX: startX, startY: startY, endX: endX, endY: endY)
        addLane(lane)
    }
    
    func addHorizontalLane(type: CampLane.LaneType, name: String, yPosition: Double) {
        guard let grid = currentLayout?.grid else { return }
        addLane(type: type, name: name, startX: 0, startY: yPosition, endX: grid.widthFeet, endY: yPosition)
    }
    
    func addVerticalLane(type: CampLane.LaneType, name: String, xPosition: Double) {
        guard let grid = currentLayout?.grid else { return }
        addLane(type: type, name: name, startX: xPosition, startY: 0, endX: xPosition, endY: grid.depthFeet)
    }
    
    func updateLane(_ laneID: UUID, updates: (inout CampLane) -> Void) {
        guard let index = currentLayout?.lanes.firstIndex(where: { $0.id == laneID }) else { return }
        updates(&currentLayout!.lanes[index])
        saveCurrentLayout()
    }
    
    func deleteLane(_ laneID: UUID) {
        currentLayout?.lanes.removeAll { $0.id == laneID }
        if selectedLane?.id == laneID {
            selectedLane = nil
        }
        saveCurrentLayout()
    }
    
    // MARK: - Grid Helpers
    private func snapToGridUnit(_ value: Double, unit: Double) -> Double {
        round(value / unit) * unit
    }
    
    func gridPositionToFeet(_ point: CGPoint, viewSize: CGSize) -> CGPoint {
        guard let grid = currentLayout?.grid else { return point }
        
        let scaleX = grid.widthFeet / Double(viewSize.width)
        let scaleY = grid.depthFeet / Double(viewSize.height)
        
        return CGPoint(
            x: Double(point.x) * scaleX,
            y: Double(point.y) * scaleY
        )
    }
    
    func feetToViewPosition(_ feet: CGPoint, viewSize: CGSize) -> CGPoint {
        guard let grid = currentLayout?.grid else { return feet }
        
        let scaleX = Double(viewSize.width) / grid.widthFeet
        let scaleY = Double(viewSize.height) / grid.depthFeet
        
        return CGPoint(
            x: feet.x * scaleX,
            y: feet.y * scaleY
        )
    }
    
    // MARK: - Statistics
    var statistics: LayoutStatistics? {
        guard let layout = currentLayout else { return nil }
        
        return LayoutStatistics(
            totalArea: layout.grid.totalSquareFeet,
            usedArea: layout.totalItemArea,
            usedPercentage: layout.usedPercentage,
            rvCount: layout.rvCount,
            vehicleCount: layout.vehicleCount,
            structureCount: layout.items.filter { $0.type == .shade || $0.type == .kitchen || $0.type == .stage }.count,
            laneCount: layout.lanes.count,
            fireLaneLength: layout.lanes.filter { $0.type == .fireLane }.reduce(0) { $0 + $1.length }
        )
    }
    
    // MARK: - Persistence
    private func loadLayouts() {
        if let data = userDefaults.data(forKey: layoutsKey),
           let decoded = try? JSONDecoder().decode([CampLayout].self, from: data) {
            savedLayouts = decoded
        }
    }
    
    private func saveLayouts() {
        if let encoded = try? JSONEncoder().encode(savedLayouts) {
            userDefaults.set(encoded, forKey: layoutsKey)
        }
    }
    
    private func loadCurrentLayout() {
        if let data = userDefaults.data(forKey: currentLayoutKey),
           let decoded = try? JSONDecoder().decode(CampLayout.self, from: data) {
            currentLayout = decoded
        }
    }
    
    private func saveCurrentLayout() {
        if let layout = currentLayout,
           let encoded = try? JSONEncoder().encode(layout) {
            userDefaults.set(encoded, forKey: currentLayoutKey)
        } else {
            userDefaults.removeObject(forKey: currentLayoutKey)
        }
    }
    
    // MARK: - Export
    func exportLayoutSummary() -> String {
        guard let layout = currentLayout else { return "" }
        
        var summary = """
        # \(layout.grid.name)
        Year: \(layout.grid.year)
        Dimensions: \(Int(layout.grid.widthFeet))' x \(Int(layout.grid.depthFeet))' (\(Int(layout.grid.totalSquareFeet)) sq ft)
        
        ## Items (\(layout.items.count))
        """
        
        let grouped = Dictionary(grouping: layout.items) { $0.type }
        for (type, items) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            summary += "\n### \(type.rawValue) (\(items.count))\n"
            for item in items {
                summary += "- \(item.name): \(Int(item.widthFeet))' x \(Int(item.depthFeet))'"
                if let assigned = item.assignedName {
                    summary += " → \(assigned)"
                }
                summary += "\n"
            }
        }
        
        if !layout.lanes.isEmpty {
            summary += "\n## Lanes (\(layout.lanes.count))\n"
            for lane in layout.lanes {
                summary += "- \(lane.name) (\(lane.type.rawValue)): \(Int(lane.widthFeet))' wide, \(Int(lane.length))' long\n"
            }
        }
        
        return summary
    }
}

// MARK: - Layout Statistics
struct LayoutStatistics {
    let totalArea: Double
    let usedArea: Double
    let usedPercentage: Double
    let rvCount: Int
    let vehicleCount: Int
    let structureCount: Int
    let laneCount: Int
    let fireLaneLength: Double
    
    var availableArea: Double {
        totalArea - usedArea
    }
}
