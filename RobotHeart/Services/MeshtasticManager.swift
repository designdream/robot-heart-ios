import Foundation
import CoreBluetooth
import Combine
import CoreLocation

/// Compatibility shim that wraps MeshtasticOrchestrator
/// This allows existing views to continue working without changes while using the new service architecture
///
/// **DEPRECATED**: New code should use `MeshtasticOrchestrator` directly via `AppEnvironment.meshtastic`
@MainActor
class MeshtasticManager: ObservableObject {
    
    // MARK: - Published Properties (Forwarded from Orchestrator)
    
    @Published var isConnected = false
    @Published var connectedDevice: String?
    @Published var connectedDeviceModel: MeshtasticHardwareModel = .unset
    @Published var campMembers: [CampMember] = []
    @Published var messages: [Message] = []
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var myNodeInfo: MeshtasticMyNodeInfo?
    @Published var nodes: [UInt32: MeshtasticNodeInfo] = [:]
    @Published var batteryLevel: Int?
    @Published var lastError: String?
    @Published var isConfigured = false
    
    // MARK: - Private Properties
    
    private let orchestrator: MeshtasticOrchestrator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(orchestrator: MeshtasticOrchestrator) {
        self.orchestrator = orchestrator
        setupForwarding()
    }
    
    convenience init() {
        // For backward compatibility - creates its own orchestrator
        let locationManager = LocationManager()
        let orchestrator = MeshtasticOrchestrator(locationManager: locationManager)
        self.init(orchestrator: orchestrator)
    }
    
    // MARK: - Setup
    
    private func setupForwarding() {
        // Forward connection state
        orchestrator.connection.$connectionStatus
            .sink { [weak self] status in
                self?.isConnected = status.isActive
                self?.connectionStatus = Self.convertConnectionStatus(status)
                self?.isConfigured = status == .ready
            }
            .store(in: &cancellables)
        
        orchestrator.connection.$discoveredDevices
            .sink { [weak self] devices in
                self?.discoveredDevices = devices.map { Self.convertDiscoveredDevice($0) }
            }
            .store(in: &cancellables)
        
        // Forward node state
        orchestrator.nodes.$campMembers
            .sink { [weak self] members in
                self?.campMembers = members
            }
            .store(in: &cancellables)
        
        orchestrator.nodes.$nodes
            .sink { [weak self] nodes in
                self?.nodes = nodes
            }
            .store(in: &cancellables)
        
        orchestrator.nodes.$myNodeInfo
            .sink { [weak self] info in
                self?.myNodeInfo = info
                if let info = info {
                    self?.connectedDevice = info.shortName
                    self?.connectedDeviceModel = info.hardwareModel
                }
            }
            .store(in: &cancellables)
        
        // Forward message state
        orchestrator.messages.$messages
            .sink { [weak self] messages in
                self?.messages = messages
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public API (Delegates to Orchestrator)
    
    func startScanning() {
        orchestrator.startScanning()
    }
    
    func stopScanning() {
        orchestrator.stopScanning()
    }
    
    func connect(to device: DiscoveredDevice) {
        // Convert back to orchestrator's type
        let orchDevice = MeshtasticConnectionService.DiscoveredDevice(
            id: device.id,
            peripheral: device.peripheral,
            name: device.name,
            rssi: device.rssi,
            lastSeen: device.lastSeen
        )
        orchestrator.connect(to: orchDevice)
    }
    
    func disconnect() {
        orchestrator.disconnect()
    }
    
    func sendMessage(_ text: String, to nodeID: UInt32? = nil) {
        try? orchestrator.sendMessage(text, to: nodeID)
    }
    
    func enableLocationSharing() {
        orchestrator.startLocationSharing()
    }
    
    func disableLocationSharing() {
        orchestrator.stopLocationSharing()
    }
    
    func requestNodeInfo(for nodeID: UInt32) {
        try? orchestrator.nodes.requestNodeInfo(for: nodeID)
    }
    
    func markMessageAsRead(_ messageID: String) {
        orchestrator.messages.markAsRead(messageID)
    }
    
    func deleteMessage(_ messageID: String) {
        orchestrator.messages.deleteMessage(messageID)
    }
    
    // MARK: - Type Conversions
    
    private static func convertConnectionStatus(_ status: MeshtasticConnectionService.ConnectionStatus) -> ConnectionStatus {
        switch status {
        case .disconnected: return .disconnected
        case .bluetoothOff: return .bluetoothOff
        case .scanning: return .scanning
        case .connecting: return .connecting
        case .connected: return .connected
        case .configuring: return .configuring
        case .ready: return .ready
        }
    }
    
    private static func convertDiscoveredDevice(_ device: MeshtasticConnectionService.DiscoveredDevice) -> DiscoveredDevice {
        return DiscoveredDevice(
            id: device.id,
            peripheral: device.peripheral,
            name: device.name,
            rssi: device.rssi,
            lastSeen: device.lastSeen
        )
    }
    
    // MARK: - Supporting Types (Kept for Compatibility)
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case bluetoothOff
        case scanning
        case connecting
        case connected
        case configuring
        case ready
        
        var description: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .bluetoothOff: return "Bluetooth Off"
            case .scanning: return "Scanning..."
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .configuring: return "Configuring..."
            case .ready: return "Ready"
            }
        }
        
        var isActive: Bool {
            switch self {
            case .connected, .configuring, .ready: return true
            default: return false
            }
        }
    }
    
    struct DiscoveredDevice: Identifiable {
        let id: UUID
        let peripheral: CBPeripheral
        let name: String
        let rssi: Int
        var lastSeen: Date
        
        var signalStrength: SignalStrength {
            switch rssi {
            case -50...0: return .excellent
            case -70..<(-50): return .good
            case -85..<(-70): return .fair
            default: return .weak
            }
        }
        
        enum SignalStrength: String {
            case excellent = "Excellent"
            case good = "Good"
            case fair = "Fair"
            case weak = "Weak"
        }
    }
}

// MARK: - Meshtastic Protocol Constants

struct MeshtasticBLE {
    static let serviceUUID = "6BA1B218-15A8-461F-9FA8-5DCAE273EAFD"
    
    struct Characteristics {
        static let fromRadio = "2C55E69E-4993-11ED-B878-0242AC120002"
        static let toRadio = "F75C76D2-129E-4DAD-A1DD-7866124401E7"
        static let fromNum = "ED9DA18C-A800-4F66-A670-AA7547E34453"
    }
}

// MARK: - Packet Types

struct MeshtasticPacket {
    let fromNodeID: UInt32
    let toNodeID: UInt32
    let portNum: PortNum
    let payload: Data
    let wantAck: Bool
    let hopLimit: UInt32
    
    enum PortNum: UInt32 {
        case textMessage = 1
        case textMessageCompressed = 2
        case position = 3
        case nodeInfo = 4
        case routing = 5
        case admin = 6
        case telemetry = 7
        case traceroute = 8
        case neighborInfo = 9
        case unknown = 999
    }
}
