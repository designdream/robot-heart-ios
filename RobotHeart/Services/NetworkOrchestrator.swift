import Foundation
import Combine

/// Orchestrates communication across multiple network layers to prevent conflicts
/// and optimize for range, bandwidth, and power consumption.
///
/// Network Layers:
/// - Meshtastic (LoRa): Long-range (5-15km), low bandwidth (~200 bytes), primary layer
/// - BLE Mesh: Short-range (10-100m), high bandwidth (~1Mbps), presence detection
///
/// Decision Logic:
/// - Messages, location, emergencies → Meshtastic (reliable, long-range)
/// - Presence detection → BLE (low power, immediate)
/// - Large data transfers → BLE when in range, otherwise queue
@MainActor
class NetworkOrchestrator: ObservableObject {
    
    // MARK: - Network Layers
    
    private let meshtastic: MeshtasticManager
    private let bleMesh: BLEMeshManager
    
    // MARK: - State
    
    @Published var isNetworkingActive = false
    @Published var preferredLayer: NetworkLayer = .meshtastic
    
    enum NetworkLayer {
        case meshtastic  // Long-range LoRa
        case ble         // Short-range Bluetooth
        case hybrid      // Both active
    }
    
    // MARK: - Initialization
    
    init(meshtastic: MeshtasticManager, bleMesh: BLEMeshManager) {
        self.meshtastic = meshtastic
        self.bleMesh = bleMesh
    }
    
    // MARK: - Lifecycle
    
    func startNetworking(userID: String, userName: String) {
        guard !isNetworkingActive else { return }
        
        // Start Meshtastic (primary layer)
        meshtastic.startScanning()
        
        // Start BLE for presence detection only
        bleMesh.startAdvertising(userID: userID, userName: userName)
        bleMesh.startScanning()
        
        isNetworkingActive = true
        preferredLayer = .hybrid
        
        print("🌐 [NetworkOrchestrator] Started networking - Meshtastic (primary) + BLE (presence)")
    }
    
    func stopNetworking() {
        guard isNetworkingActive else { return }
        
        // Stop both layers
        meshtastic.disconnect()
        bleMesh.stopAdvertising()
        bleMesh.stopScanning()
        
        isNetworkingActive = false
        
        print("🌐 [NetworkOrchestrator] Stopped networking")
    }
    
    func pauseNetworking() {
        guard isNetworkingActive else { return }
        
        // Reduce BLE scanning frequency to save power
        bleMesh.stopScanning()
        
        // Meshtastic stays active (low power by design)
        
        print("🌐 [NetworkOrchestrator] Paused networking (BLE scanning stopped)")
    }
    
    func resumeNetworking() {
        guard isNetworkingActive else { return }
        
        // Resume BLE scanning
        bleMesh.startScanning()
        
        print("🌐 [NetworkOrchestrator] Resumed networking")
    }
    
    // MARK: - Routing Logic
    
    /// Determine which network layer to use for a given message type
    func routeMessage(type: MessageType) -> NetworkLayer {
        switch type {
        case .text, .announcement, .emergency, .location:
            // Always use Meshtastic for critical, long-range messages
            return .meshtastic
            
        case .presence:
            // Use BLE for immediate presence detection
            return .ble
            
        case .largeData:
            // Use BLE if peers are in range, otherwise queue for later
            return bleMesh.connectedPeers.isEmpty ? .meshtastic : .ble
        }
    }
    
    enum MessageType {
        case text
        case announcement
        case emergency
        case location
        case presence
        case largeData
    }
    
    // MARK: - Send Methods
    
    /// Send a text message via the appropriate network layer
    func sendTextMessage(_ content: String, to recipient: String? = nil) {
        let layer = routeMessage(type: .text)
        
        switch layer {
        case .meshtastic:
            meshtastic.sendMessage(content, type: .text)
            print("📡 [NetworkOrchestrator] Sent text via Meshtastic")
            
        case .ble:
            // BLE not used for text messages (use Meshtastic for reliability)
            meshtastic.sendMessage(content, type: .text)
            print("📡 [NetworkOrchestrator] Fallback: Sent text via Meshtastic")
            
        case .hybrid:
            // Send via Meshtastic (primary)
            meshtastic.sendMessage(content, type: .text)
            print("📡 [NetworkOrchestrator] Sent text via Meshtastic (hybrid mode)")
        }
    }
    
    /// Send location update via Meshtastic
    func sendLocation(latitude: Double, longitude: Double) {
        meshtastic.sendLocation(latitude: latitude, longitude: longitude)
        print("📍 [NetworkOrchestrator] Sent location via Meshtastic")
    }
    
    /// Broadcast emergency alert via Meshtastic
    func sendEmergency(message: String, location: (Double, Double)?) {
        meshtastic.sendEmergency()
        print("🚨 [NetworkOrchestrator] Sent emergency via Meshtastic")
    }
    
    /// Update presence via BLE (lightweight, immediate)
    func updatePresence(status: String) {
        // BLE presence is handled automatically by advertising
        // This method can be used to update the advertised data
        print("👋 [NetworkOrchestrator] Updated presence via BLE")
    }
    
    // MARK: - Network Health
    
    var networkHealth: NetworkHealth {
        let meshtasticConnected = meshtastic.isConnected
        let bleConnected = !bleMesh.connectedPeers.isEmpty
        
        if meshtasticConnected && bleConnected {
            return .excellent
        } else if meshtasticConnected {
            return .good
        } else if bleConnected {
            return .limited
        } else {
            return .offline
        }
    }
    
    enum NetworkHealth {
        case excellent  // Both layers active
        case good       // Meshtastic active
        case limited    // Only BLE active
        case offline    // No connectivity
        
        var description: String {
            switch self {
            case .excellent: return "Excellent (LoRa + BLE)"
            case .good: return "Good (LoRa)"
            case .limited: return "Limited (BLE only)"
            case .offline: return "Offline"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "4CAF50"  // Green
            case .good: return "8BC34A"       // Light Green
            case .limited: return "FF9800"    // Orange
            case .offline: return "F44336"    // Red
            }
        }
    }
}
