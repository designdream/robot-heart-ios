import Foundation
import Combine
import CoreLocation

/// Service responsible for managing Meshtastic mesh network nodes.
/// Handles node discovery, tracking, and metadata management.
@MainActor
class MeshtasticNodeService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var nodes: [UInt32: MeshtasticNodeInfo] = [:]
    @Published var myNodeInfo: MeshtasticMyNodeInfo?
    @Published var campMembers: [CampMember] = []
    
    // MARK: - Private Properties
    
    private let protocolService = MeshtasticProtocolService.shared
    private let userDefaults = UserDefaults.standard
    private let nodesKey = "meshtastic_nodes"
    private var cancellables = Set<AnyCancellable>()
    
    // Callback for sending data
    var sendData: ((Data) throws -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadPersistedNodes()
        
        // Load demo members if no real members exist (for testing without device)
        if campMembers.isEmpty {
            loadDemoMembers()
        }
    }
    
    // MARK: - Public Methods
    
    /// Add or update a node in the network
    func addOrUpdateNode(_ nodeInfo: MeshtasticNodeInfo) {
        nodes[nodeInfo.nodeID] = nodeInfo
        updateCampMembers()
        persistNodes()
        
        print("📡 [MeshtasticNode] Updated node: \(nodeInfo.shortName ?? "Unknown") (\(nodeInfo.nodeID))")
    }
    
    /// Remove a node from the network
    func removeNode(_ nodeID: UInt32) {
        nodes.removeValue(forKey: nodeID)
        updateCampMembers()
        persistNodes()
        
        print("📡 [MeshtasticNode] Removed node: \(nodeID)")
    }
    
    /// Get a node by ID
    func getNode(_ nodeID: UInt32) -> MeshtasticNodeInfo? {
        return nodes[nodeID]
    }
    
    /// Get all nodes as an array
    func getAllNodes() -> [MeshtasticNodeInfo] {
        return Array(nodes.values).sorted { $0.lastHeard > $1.lastHeard }
    }
    
    /// Request node info from a specific node
    func requestNodeInfo(for nodeID: UInt32) throws {
        let packet = try protocolService.encodeNodeInfoRequest(for: nodeID)
        try sendData?(packet)
        
        print("📡 [MeshtasticNode] Requested node info for: \(nodeID)")
    }
    
    /// Set the current device's node info
    func setMyNodeInfo(_ nodeInfo: MeshtasticMyNodeInfo) {
        myNodeInfo = nodeInfo
        
        // Also add to nodes list
        let fullNodeInfo = MeshtasticNodeInfo(
            nodeID: nodeInfo.myNodeNum,
            shortName: nodeInfo.shortName,
            longName: nodeInfo.longName,
            hardwareModel: nodeInfo.hardwareModel,
            firmwareVersion: nodeInfo.firmwareVersion,
            lastHeard: Date(),
            position: nil,
            batteryLevel: nil
        )
        addOrUpdateNode(fullNodeInfo)
        
        print("📡 [MeshtasticNode] Set my node info: \(nodeInfo.shortName)")
    }
    
    /// Update node location
    func updateNodeLocation(_ nodeID: UInt32, location: CLLocation) {
        guard var node = nodes[nodeID] else { return }
        
        node.position = location
        node.lastHeard = Date()
        nodes[nodeID] = node
        
        updateCampMembers()
        persistNodes()
        
        print("📡 [MeshtasticNode] Updated location for node: \(nodeID)")
    }
    
    /// Update node battery level
    func updateNodeBattery(_ nodeID: UInt32, batteryLevel: Int) {
        guard var node = nodes[nodeID] else { return }
        
        node.batteryLevel = batteryLevel
        node.lastHeard = Date()
        nodes[nodeID] = node
        
        updateCampMembers()
        persistNodes()
        
        print("📡 [MeshtasticNode] Updated battery for node: \(nodeID) -> \(batteryLevel)%")
    }
    
    /// Mark a node as recently heard
    func markNodeAsHeard(_ nodeID: UInt32) {
        guard var node = nodes[nodeID] else { return }
        
        node.lastHeard = Date()
        nodes[nodeID] = node
        
        updateCampMembers()
        persistNodes()
    }
    
    /// Clear all nodes (for testing/reset)
    func clearAllNodes() {
        nodes.removeAll()
        campMembers.removeAll()
        myNodeInfo = nil
        persistNodes()
        
        // Reload demo members
        loadDemoMembers()
        
        print("📡 [MeshtasticNode] Cleared all nodes")
    }
    
    // MARK: - Private Methods
    
    private func updateCampMembers() {
        // Convert Meshtastic nodes to CampMembers
        campMembers = nodes.values.map { node in
            let lastSeen = node.lastHeard
            let timeSinceLastSeen = Date().timeIntervalSince(lastSeen)
            
            let status: CampMember.Status
            if timeSinceLastSeen < 300 { // 5 minutes
                status = .connected
            } else if timeSinceLastSeen < 3600 { // 1 hour
                status = .recent
            } else {
                status = .offline
            }
            
            return CampMember(
                id: "\(node.nodeID)",
                name: node.shortName ?? "Node \(node.nodeID)",
                role: .member,
                location: node.position,
                lastSeen: lastSeen,
                batteryLevel: node.batteryLevel,
                status: status,
                currentShift: nil
            )
        }
        .sorted { $0.lastSeen > $1.lastSeen }
    }
    
    private func persistNodes() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(Array(nodes.values)) {
            userDefaults.set(encoded, forKey: nodesKey)
        }
    }
    
    private func loadPersistedNodes() {
        guard let data = userDefaults.data(forKey: nodesKey) else { return }
        
        let decoder = JSONDecoder()
        if let nodeArray = try? decoder.decode([MeshtasticNodeInfo].self, from: data) {
            nodes = Dictionary(uniqueKeysWithValues: nodeArray.map { ($0.nodeID, $0) })
            updateCampMembers()
            print("📡 [MeshtasticNode] Loaded \(nodes.count) persisted nodes")
        }
    }
    
    /// Load demo camp members for testing without a Meshtastic device
    private func loadDemoMembers() {
        campMembers = [
            CampMember(
                id: "demo-1",
                name: "Felipe",
                role: .lead,
                location: nil,
                lastSeen: Date(),
                batteryLevel: 85,
                status: .connected,
                currentShift: nil
            ),
            CampMember(
                id: "demo-2",
                name: "DJ Sparkle",
                role: .bus,
                location: nil,
                lastSeen: Date().addingTimeInterval(-300),
                batteryLevel: 72,
                status: .connected,
                currentShift: nil
            ),
            CampMember(
                id: "demo-3",
                name: "Luna",
                role: .shadyBot,
                location: nil,
                lastSeen: Date().addingTimeInterval(-1800),
                batteryLevel: 45,
                status: .recent,
                currentShift: nil
            ),
            CampMember(
                id: "demo-4",
                name: "Dusty Dave",
                role: .build,
                location: nil,
                lastSeen: Date().addingTimeInterval(-7200),
                batteryLevel: nil,
                status: .offline,
                currentShift: nil
            )
        ]
        
        print("📡 [MeshtasticNode] Loaded \(campMembers.count) demo members")
    }
}

// MARK: - Supporting Types

struct MeshtasticNodeInfo: Codable {
    let nodeID: UInt32
    var shortName: String?
    var longName: String?
    var hardwareModel: MeshtasticHardwareModel
    var firmwareVersion: String?
    var lastHeard: Date
    var position: CLLocation?
    var batteryLevel: Int?
    
    enum CodingKeys: String, CodingKey {
        case nodeID, shortName, longName, hardwareModel, firmwareVersion, lastHeard, batteryLevel
        case latitude, longitude, altitude, timestamp
    }
    
    init(nodeID: UInt32, shortName: String?, longName: String?, hardwareModel: MeshtasticHardwareModel, firmwareVersion: String?, lastHeard: Date, position: CLLocation?, batteryLevel: Int?) {
        self.nodeID = nodeID
        self.shortName = shortName
        self.longName = longName
        self.hardwareModel = hardwareModel
        self.firmwareVersion = firmwareVersion
        self.lastHeard = lastHeard
        self.position = position
        self.batteryLevel = batteryLevel
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        nodeID = try container.decode(UInt32.self, forKey: .nodeID)
        shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
        longName = try container.decodeIfPresent(String.self, forKey: .longName)
        hardwareModel = try container.decode(MeshtasticHardwareModel.self, forKey: .hardwareModel)
        firmwareVersion = try container.decodeIfPresent(String.self, forKey: .firmwareVersion)
        lastHeard = try container.decode(Date.self, forKey: .lastHeard)
        batteryLevel = try container.decodeIfPresent(Int.self, forKey: .batteryLevel)
        
        // Decode location if available
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .latitude),
           let longitude = try container.decodeIfPresent(Double.self, forKey: .longitude) {
            let altitude = try container.decodeIfPresent(Double.self, forKey: .altitude) ?? 0
            let timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) ?? lastHeard
            position = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                altitude: altitude,
                horizontalAccuracy: 0,
                verticalAccuracy: 0,
                timestamp: timestamp
            )
        } else {
            position = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeID, forKey: .nodeID)
        try container.encodeIfPresent(shortName, forKey: .shortName)
        try container.encodeIfPresent(longName, forKey: .longName)
        try container.encode(hardwareModel, forKey: .hardwareModel)
        try container.encodeIfPresent(firmwareVersion, forKey: .firmwareVersion)
        try container.encode(lastHeard, forKey: .lastHeard)
        try container.encodeIfPresent(batteryLevel, forKey: .batteryLevel)
        
        // Encode location if available
        if let position = position {
            try container.encode(position.coordinate.latitude, forKey: .latitude)
            try container.encode(position.coordinate.longitude, forKey: .longitude)
            try container.encode(position.altitude, forKey: .altitude)
            try container.encode(position.timestamp, forKey: .timestamp)
        }
    }
}

struct MeshtasticMyNodeInfo {
    let myNodeNum: UInt32
    let shortName: String
    let longName: String
    let hardwareModel: MeshtasticHardwareModel
    let firmwareVersion: String
    let publicKey: Data?
}

enum MeshtasticHardwareModel: String, Codable {
    case unset = "UNSET"
    case t1000E = "T1000-E"
    case sensecapT1000 = "SenseCAP_T1000"
    case rakWisMeshTag = "RAK_WisMesh_Tag"
    case rakWisMeshPocket = "RAK_WisMesh_Pocket"
    case tbeam = "TBEAM"
    case tlora = "TLORA"
    case heltecV3 = "HELTEC_V3"
    case other = "OTHER"
}
