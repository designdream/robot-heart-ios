import Foundation
import Combine
import CoreLocation

/// Orchestrator that coordinates all Meshtastic services.
/// This is the main entry point for Meshtastic functionality.
@MainActor
class MeshtasticOrchestrator: ObservableObject {
    
    // MARK: - Services
    
    let connection: MeshtasticConnectionService
    let nodes: MeshtasticNodeService
    let messages: MeshtasticMessageService
    let location: MeshtasticLocationService
    
    // MARK: - Published State (Aggregated)
    
    @Published var isConnected: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let locationManager: LocationManager
    
    // MARK: - Initialization
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
        
        // Initialize all services
        self.connection = MeshtasticConnectionService()
        self.nodes = MeshtasticNodeService()
        self.messages = MeshtasticMessageService()
        self.location = MeshtasticLocationService()
        
        // Wire up services
        setupServiceCallbacks()
        setupPublishers()
        
        print("🎯 [MeshtasticOrchestrator] Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for Meshtastic devices
    func startScanning() {
        connection.startScanning()
    }
    
    /// Stop scanning
    func stopScanning() {
        connection.stopScanning()
    }
    
    /// Connect to a device
    func connect(to device: MeshtasticConnectionService.DiscoveredDevice) {
        connection.connect(to: device)
    }
    
    /// Disconnect from current device
    func disconnect() {
        connection.disconnect()
        location.stopLocationSharing()
    }
    
    /// Send a text message
    func sendMessage(_ text: String, to nodeID: UInt32? = nil) throws {
        try messages.sendMessage(text, to: nodeID)
    }
    
    /// Enable location sharing
    func startLocationSharing() {
        location.startLocationSharing()
    }
    
    /// Disable location sharing
    func stopLocationSharing() {
        location.stopLocationSharing()
    }
    
    /// Get all camp members (from nodes)
    func getCampMembers() -> [CampMember] {
        return nodes.campMembers
    }
    
    /// Get all messages
    func getMessages() -> [Message] {
        return messages.messages
    }
    
    /// Get connection status
    func getConnectionStatus() -> MeshtasticConnectionService.ConnectionStatus {
        return connection.connectionStatus
    }
    
    // MARK: - Private Methods
    
    private func setupServiceCallbacks() {
        // Connection -> Messages & Location
        connection.onDataReceived = { [weak self] data in
            Task { @MainActor in
                self?.handleReceivedData(data)
            }
        }
        
        connection.onConnectionReady = { [weak self] in
            Task { @MainActor in
                self?.handleConnectionReady()
            }
        }
        
        // Messages -> Connection
        messages.sendData = { [weak self] data in
            guard let self = self else { return }
            if !self.connection.sendData(data) {
                throw MeshtasticError.notConnected
            }
        }
        
        // Nodes -> Connection
        nodes.sendData = { [weak self] data in
            guard let self = self else { return }
            if !self.connection.sendData(data) {
                throw MeshtasticError.notConnected
            }
        }
        
        // Location -> Connection
        location.sendData = { [weak self] data in
            guard let self = self else { return }
            if !self.connection.sendData(data) {
                throw MeshtasticError.notConnected
            }
        }
        
        // Location -> LocationManager
        location.getCurrentLocation = { [weak self] in
            return self?.locationManager.currentLocation
        }
        
        // Location -> Nodes
        location.onLocationReceived = { [weak self] nodeID, location in
            self?.nodes.updateNodeLocation(nodeID, location: location)
        }
        
        // Messages -> Nodes (mark as heard)
        messages.onMessageReceived = { [weak self] message in
            if let nodeID = UInt32(message.senderID) {
                self?.nodes.markNodeAsHeard(nodeID)
            }
        }
    }
    
    private func setupPublishers() {
        // Aggregate connection status
        connection.$connectionStatus
            .sink { [weak self] status in
                self?.isConnected = status.isActive
                self?.connectionStatus = status.description
            }
            .store(in: &cancellables)
    }
    
    private func handleReceivedData(_ data: Data) {
        do {
            // Try to decode as a packet
            let packet = try MeshtasticProtocolService.shared.decodePacket(data)
            
            // Route to appropriate service
            switch packet.portNum {
            case .textMessage, .textMessageCompressed:
                messages.processReceivedPacket(data)
                
            case .position:
                location.processReceivedPacket(packet)
                
            case .nodeInfo:
                // TODO: Handle node info packets
                print("📡 [MeshtasticOrchestrator] Received node info packet")
                
            default:
                print("📡 [MeshtasticOrchestrator] Received packet with port: \(packet.portNum)")
            }
            
        } catch {
            print("❌ [MeshtasticOrchestrator] Failed to process received data: \(error.localizedDescription)")
        }
    }
    
    private func handleConnectionReady() {
        print("🎉 [MeshtasticOrchestrator] Connection ready!")
        
        // Auto-start location sharing if it was enabled
        if location.isLocationSharingEnabled {
            location.startLocationSharing()
        }
    }
}

// MARK: - Error Types

enum MeshtasticError: LocalizedError {
    case notConnected
    case sendFailed
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to a Meshtastic device"
        case .sendFailed:
            return "Failed to send data"
        }
    }
}
