import Foundation
import SwiftUI

// MARK: - Camp Grid Configuration
struct CampGrid: Codable {
    var widthFeet: Double           // Total width in feet (from placement)
    var depthFeet: Double           // Total depth in feet (from placement)
    var gridUnitFeet: Double        // Grid snap unit (default 5 feet)
    var name: String
    var year: Int
    var createdAt: Date
    var updatedAt: Date
    
    init(widthFeet: Double, depthFeet: Double, gridUnitFeet: Double = 5, name: String = "Camp Layout") {
        self.widthFeet = widthFeet
        self.depthFeet = depthFeet
        self.gridUnitFeet = gridUnitFeet
        self.name = name
        self.year = Calendar.current.component(.year, from: Date())
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    var gridColumns: Int {
        Int(widthFeet / gridUnitFeet)
    }
    
    var gridRows: Int {
        Int(depthFeet / gridUnitFeet)
    }
    
    var totalSquareFeet: Double {
        widthFeet * depthFeet
    }
}

// MARK: - Placeable Item (anything on the grid)
struct PlaceableItem: Identifiable, Codable {
    let id: UUID
    var type: ItemType
    var name: String
    var widthFeet: Double
    var depthFeet: Double
    var xPosition: Double           // Position in feet from left
    var yPosition: Double           // Position in feet from top
    var rotation: Double            // Degrees (0, 90, 180, 270)
    var color: String               // Hex color
    var notes: String?
    var assignedTo: String?         // Member ID for RVs
    var assignedName: String?
    
    enum ItemType: String, Codable, CaseIterable {
        case rv = "RV"
        case trailer = "Trailer"
        case tent = "Tent"
        case car = "Car"
        case truck = "Truck"
        case artCar = "Art Car"
        case kitchen = "Kitchen"
        case shade = "Shade Structure"
        case stage = "Stage"
        case generator = "Generator"
        case waterTank = "Water Tank"
        case portaPotty = "Porta Potty"
        case storage = "Storage"
        case lounge = "Lounge Area"
        case custom = "Custom"
        
        var icon: String {
            switch self {
            case .rv: return "bus.fill"
            case .trailer: return "box.truck.fill"
            case .tent: return "tent.fill"
            case .car: return "car.fill"
            case .truck: return "truck.box.fill"
            case .artCar: return "sparkles"
            case .kitchen: return "fork.knife"
            case .shade: return "sun.max.fill"
            case .stage: return "music.note.house.fill"
            case .generator: return "bolt.fill"
            case .waterTank: return "drop.fill"
            case .portaPotty: return "toilet.fill"
            case .storage: return "shippingbox.fill"
            case .lounge: return "sofa.fill"
            case .custom: return "square.dashed"
            }
        }
        
        var defaultColor: String {
            switch self {
            case .rv: return "4ECDC4"
            case .trailer: return "9C27B0"
            case .tent: return "FFB300"
            case .car: return "2196F3"
            case .truck: return "607D8B"
            case .artCar: return "E91E63"
            case .kitchen: return "FF5722"
            case .shade: return "FFEB3B"
            case .stage: return "D84315"
            case .generator: return "FFC107"
            case .waterTank: return "03A9F4"
            case .portaPotty: return "795548"
            case .storage: return "9E9E9E"
            case .lounge: return "8BC34A"
            case .custom: return "E8DCC8"
            }
        }
        
        // Common preset sizes (width x depth in feet)
        var presetSizes: [(name: String, width: Double, depth: Double)] {
            switch self {
            case .rv:
                return [
                    // Class A Motorhomes
                    ("Class A - 28'", 8.5, 28),
                    ("Class A - 32'", 8.5, 32),
                    ("Class A - 36'", 8.5, 36),
                    ("Class A - 40'", 8.5, 40),
                    ("Class A - 45'", 8.5, 45),
                    // Class B (Camper Vans)
                    ("Class B - Sprinter", 6.5, 22),
                    ("Class B - ProMaster", 6.5, 21),
                    ("Class B - Transit", 6.5, 20),
                    // Class C Motorhomes
                    ("Class C - 22'", 8, 22),
                    ("Class C - 26'", 8, 26),
                    ("Class C - 30'", 8.5, 30),
                    ("Class C - 32'", 8.5, 32)
                ]
            case .trailer:
                return [
                    // Travel Trailers
                    ("Travel Trailer - 18'", 7, 18),
                    ("Travel Trailer - 22'", 8, 22),
                    ("Travel Trailer - 26'", 8, 26),
                    ("Travel Trailer - 30'", 8, 30),
                    // Fifth Wheels
                    ("Fifth Wheel - 28'", 8, 28),
                    ("Fifth Wheel - 32'", 8, 32),
                    ("Fifth Wheel - 36'", 8.5, 36),
                    ("Fifth Wheel - 40'", 8.5, 40),
                    // Toy Haulers
                    ("Toy Hauler - 24'", 8.5, 24),
                    ("Toy Hauler - 30'", 8.5, 30)
                ]
            case .tent:
                return [
                    ("2-Person", 5, 7),
                    ("4-Person", 8, 8),
                    ("6-Person", 10, 10),
                    ("Dome (12')", 12, 12),
                    ("Large Dome (16')", 16, 16)
                ]
            case .car:
                return [
                    ("Compact", 6, 14),
                    ("Sedan", 6, 16),
                    ("SUV", 6.5, 17),
                    ("Large SUV", 7, 18)
                ]
            case .truck:
                return [
                    ("Pickup", 7, 19),
                    ("Box Truck (16')", 8, 24),
                    ("Box Truck (24')", 8.5, 32)
                ]
            case .artCar:
                return [
                    ("Robot Heart Bus", 8.5, 45)
                ]
            case .kitchen:
                return [
                    ("Small Kitchen", 10, 10),
                    ("Medium Kitchen", 15, 15),
                    ("Large Kitchen", 20, 20)
                ]
            case .shade:
                return [
                    ("10x10 Canopy", 10, 10),
                    ("10x20 Canopy", 10, 20),
                    ("20x20 Structure", 20, 20),
                    ("20x40 Structure", 20, 40),
                    ("Hexayurt", 12, 12)
                ]
            case .stage:
                return [
                    ("Small Stage", 16, 12),
                    ("Medium Stage", 24, 16),
                    ("Large Stage", 32, 20)
                ]
            case .generator:
                return [
                    ("Honda EU2200i", 2, 2),
                    ("Honda EU3000is", 2.5, 2),
                    ("Honda EU7000is", 3, 2.5),
                    ("Generac 7500W", 3, 3),
                    ("Large Diesel Gen", 4, 6),
                    ("Towable Gen (20kW)", 5, 8)
                ]
            case .waterTank:
                return [
                    ("55 Gal Drum", 2, 2),
                    ("100 Gal Tank", 3, 3),
                    ("250 Gal Tank", 4, 4),
                    ("500 Gal Tank", 5, 8),
                    ("Water Buffalo (400 Gal)", 6, 10),
                    ("1000 Gal Tank", 6, 12)
                ]
            case .portaPotty:
                return [
                    ("Single Porta", 4, 4),
                    ("ADA Accessible", 5, 5),
                    ("Double Unit", 8, 4),
                    ("Quad Unit", 8, 8),
                    ("Shower/Toilet Combo", 6, 8)
                ]
            case .storage:
                return [
                    ("Small Container", 8, 10),
                    ("Shipping Container (20')", 8, 20),
                    ("Shipping Container (40')", 8, 40)
                ]
            case .lounge:
                return [
                    ("Small Lounge", 10, 10),
                    ("Medium Lounge", 15, 15),
                    ("Large Lounge", 20, 20)
                ]
            case .custom:
                return [
                    ("10x10", 10, 10),
                    ("20x20", 20, 20)
                ]
            }
        }
    }
    
    init(
        type: ItemType,
        name: String,
        widthFeet: Double,
        depthFeet: Double,
        xPosition: Double = 0,
        yPosition: Double = 0,
        rotation: Double = 0
    ) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.widthFeet = widthFeet
        self.depthFeet = depthFeet
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.rotation = rotation
        self.color = type.defaultColor
    }
    
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    // Effective dimensions after rotation
    var effectiveWidth: Double {
        rotation == 90 || rotation == 270 ? depthFeet : widthFeet
    }
    
    var effectiveDepth: Double {
        rotation == 90 || rotation == 270 ? widthFeet : depthFeet
    }
    
    var area: Double {
        widthFeet * depthFeet
    }
    
    // Bounding box for collision detection
    var bounds: CGRect {
        CGRect(x: xPosition, y: yPosition, width: effectiveWidth, height: effectiveDepth)
    }
    
    func intersects(_ other: PlaceableItem) -> Bool {
        bounds.intersects(other.bounds)
    }
}

// MARK: - Lane (fire lane, road, pathway)
struct CampLane: Identifiable, Codable {
    let id: UUID
    var type: LaneType
    var name: String
    var startX: Double
    var startY: Double
    var endX: Double
    var endY: Double
    var widthFeet: Double
    
    enum LaneType: String, Codable, CaseIterable {
        case fireLane = "Fire Lane"
        case mainRoad = "Main Road"
        case pathway = "Pathway"
        case entrance = "Entrance"
        case emergency = "Emergency Access"
        
        var color: Color {
            switch self {
            case .fireLane: return Color.red.opacity(0.3)
            case .mainRoad: return Color.gray.opacity(0.4)
            case .pathway: return Color.brown.opacity(0.3)
            case .entrance: return Color.green.opacity(0.3)
            case .emergency: return Color.orange.opacity(0.3)
            }
        }
        
        var minWidthFeet: Double {
            switch self {
            case .fireLane: return 20      // Burning Man requirement for camps > 100'x100'
            case .mainRoad: return 15
            case .pathway: return 6
            case .entrance: return 20
            case .emergency: return 20
            }
        }
        
        var description: String {
            switch self {
            case .fireLane: return "Required 20' minimum for camps larger than 100'×100' (per Burning Man)"
            case .mainRoad: return "Main vehicle access road"
            case .pathway: return "Pedestrian walkway"
            case .entrance: return "Camp entrance/exit point"
            case .emergency: return "Emergency vehicle access"
            }
        }
        
        var icon: String {
            switch self {
            case .fireLane: return "flame.fill"
            case .mainRoad: return "road.lanes"
            case .pathway: return "figure.walk"
            case .entrance: return "arrow.right.circle.fill"
            case .emergency: return "cross.case.fill"
            }
        }
    }
    
    init(type: LaneType, name: String, startX: Double, startY: Double, endX: Double, endY: Double) {
        self.id = UUID()
        self.type = type
        self.name = name
        self.startX = startX
        self.startY = startY
        self.endX = endX
        self.endY = endY
        self.widthFeet = type.minWidthFeet
    }
    
    var isHorizontal: Bool {
        abs(startY - endY) < 1
    }
    
    var isVertical: Bool {
        abs(startX - endX) < 1
    }
    
    var length: Double {
        sqrt(pow(endX - startX, 2) + pow(endY - startY, 2))
    }
}

// MARK: - Camp Layout (complete layout)
struct CampLayout: Identifiable, Codable {
    let id: UUID
    var grid: CampGrid
    var items: [PlaceableItem]
    var lanes: [CampLane]
    var notes: String?
    var isFinalized: Bool
    
    init(grid: CampGrid) {
        self.id = UUID()
        self.grid = grid
        self.items = []
        self.lanes = []
        self.isFinalized = false
    }
    
    // Statistics
    var totalItemArea: Double {
        items.reduce(0) { $0 + $1.area }
    }
    
    var usedPercentage: Double {
        (totalItemArea / grid.totalSquareFeet) * 100
    }
    
    var rvCount: Int {
        items.filter { $0.type == .rv || $0.type == .trailer }.count
    }
    
    var vehicleCount: Int {
        items.filter { $0.type == .car || $0.type == .truck }.count
    }
    
    // Validation
    func itemsOutOfBounds() -> [PlaceableItem] {
        items.filter { item in
            item.xPosition < 0 ||
            item.yPosition < 0 ||
            item.xPosition + item.effectiveWidth > grid.widthFeet ||
            item.yPosition + item.effectiveDepth > grid.depthFeet
        }
    }
    
    func overlappingItems() -> [(PlaceableItem, PlaceableItem)] {
        var overlaps: [(PlaceableItem, PlaceableItem)] = []
        for i in 0..<items.count {
            for j in (i+1)..<items.count {
                if items[i].intersects(items[j]) {
                    overlaps.append((items[i], items[j]))
                }
            }
        }
        return overlaps
    }
    
    var hasValidationErrors: Bool {
        !itemsOutOfBounds().isEmpty || !overlappingItems().isEmpty || requiresFireLaneButMissing
    }
    
    // Fire lane requirement per Burning Man: camps > 100'x100' need 20' fire lane
    var requiresFireLane: Bool {
        grid.widthFeet > 100 || grid.depthFeet > 100
    }
    
    var hasFireLane: Bool {
        lanes.contains { $0.type == .fireLane }
    }
    
    var requiresFireLaneButMissing: Bool {
        requiresFireLane && !hasFireLane
    }
}

// MARK: - Preset RV Sizes (common models)
struct RVPreset: Identifiable {
    let id = UUID()
    let name: String
    let widthFeet: Double
    let lengthFeet: Double
    let category: String
    
    static let presets: [RVPreset] = [
        // Class A
        RVPreset(name: "Class A - Small", widthFeet: 8.5, lengthFeet: 28, category: "Class A"),
        RVPreset(name: "Class A - Medium", widthFeet: 8.5, lengthFeet: 34, category: "Class A"),
        RVPreset(name: "Class A - Large", widthFeet: 8.5, lengthFeet: 40, category: "Class A"),
        
        // Class C
        RVPreset(name: "Class C - Small", widthFeet: 8, lengthFeet: 22, category: "Class C"),
        RVPreset(name: "Class C - Medium", widthFeet: 8, lengthFeet: 28, category: "Class C"),
        RVPreset(name: "Class C - Large", widthFeet: 8.5, lengthFeet: 32, category: "Class C"),
        
        // Travel Trailers
        RVPreset(name: "Travel Trailer - Small", widthFeet: 7, lengthFeet: 18, category: "Travel Trailer"),
        RVPreset(name: "Travel Trailer - Medium", widthFeet: 8, lengthFeet: 24, category: "Travel Trailer"),
        RVPreset(name: "Travel Trailer - Large", widthFeet: 8, lengthFeet: 30, category: "Travel Trailer"),
        
        // Fifth Wheels
        RVPreset(name: "Fifth Wheel - Medium", widthFeet: 8, lengthFeet: 32, category: "Fifth Wheel"),
        RVPreset(name: "Fifth Wheel - Large", widthFeet: 8.5, lengthFeet: 40, category: "Fifth Wheel"),
        
        // Vans
        RVPreset(name: "Sprinter Van", widthFeet: 6.5, lengthFeet: 22, category: "Van"),
        RVPreset(name: "Camper Van", widthFeet: 6, lengthFeet: 18, category: "Van"),
        
        // Buses
        RVPreset(name: "School Bus Conversion", widthFeet: 8, lengthFeet: 35, category: "Bus"),
        RVPreset(name: "Coach Bus", widthFeet: 8.5, lengthFeet: 45, category: "Bus")
    ]
}
