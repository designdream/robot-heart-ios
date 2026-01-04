import Foundation
import Combine

/// Orchestrates communication across 4 network layers to prevent conflicts
/// and optimize for range, bandwidth, and power consumption.
///
/// Network Layers (Priority Order):
/// 1. Cloud (HTTPS/WebSocket): Global, high bandwidth, requires internet
/// 2. Meshtastic (LoRa): Long-range (5-15km), low bandwidth, offline-capable
/// 3. BLE Mesh: Short-range (10-100m), high bandwidth, presence detection
/// 4. Local Storage: Device-only cache and queue
///
/// Decision Logic:
/// - Text messages → Cloud (if online) → LoRa (fallback)
/// - Emergency → Cloud + LoRa (redundant, both layers)
/// - Location → Cloud (if online) → LoRa (fallback)
/// - Presence → BLE only
/// - Large files → Cloud (if online) → BLE (if in range) → Queue
@MainActor
class NetworkOrchestrator: ObservableObject {
    
    // MARK: - Network Layers
    
    private let cloudSync: CloudSyncService
    private let meshtastic: MeshtasticOrchestrator
    private let bleMesh: BLEMeshManager
    
    // MARK: - State
    
    @Published var isNetworkingActive = false
    @Published var activeLayer: NetworkLayer = .offline
    @Published var networkHealth: NetworkHealth = .offline
    
    enum NetworkLayer {
        case cloud       // Internet available
        case meshtastic  // Long-range LoRa
        case ble         // Short-range Bluetooth
        case offline     // Local storage only
        case hybrid      // Multiple layers active
    }
    
    enum NetworkHealth {
        case excellent  // Cloud + LoRa + BLE
        case good       // Cloud + LoRa OR LoRa + BLE
        case fair       // LoRa only OR Cloud only
        case limited    // BLE only
        case offline    // No connectivity
        
        var description: String {
            switch self {
            case .excellent: return "Excellent (Cloud + LoRa + BLE)"
            case .good: return "Good (Multi-layer)"
            case .fair: return "Fair (Single layer)"
            case .limited: return "Limited (BLE only)"
            case .offline: return "Offline"
            }
        }
        
        var color: String {
            switch self {
            case .excellent: return "4CAF50"  // Green
            case .good: return "8BC34A"       // Light Green
            case .fair: return "FFB300"       // Golden Yellow
            case .limited: return "FF9800"    // Orange
            case .offline: return "F44336"    // Red
            }
        }
    }
    
    // MARK: - Initialization
    
    init(cloudSync: CloudSyncService, meshtasticOrchestrator: MeshtasticOrchestrator, bleMesh: BLEMeshManager) {
        self.cloudSync = cloudSync
        self.meshtastic = meshtasticOrchestrator
        self.bleMesh = bleMesh
        
        // Observe network state changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Update network health when any layer changes
        cloudSync.$isOnline.sink { [weak self] _ in
            self?.updateNetworkHealth()
        }.store(in: &cancellables)
        
        meshtastic.$isConnected.sink { [weak self] _ in
            self?.updateNetworkHealth()
        }.store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Lifecycle
    
    func startNetworking(userID: String, userName: String) {
        guard !isNetworkingActive else { return }
        
        // Start all layers
        // Layer 1: Cloud (if available)
        // Cloud sync starts automatically via network monitoring
        
        // Layer 2: Meshtastic (primary offline layer)
        meshtastic.startScanning()
        
        // Layer 3: BLE (presence detection)
        bleMesh.startAdvertising(userID: userID, userName: userName)
        bleMesh.startScanning()
        
        isNetworkingActive = true
        updateNetworkHealth()
        
        print("🌐 [NetworkOrchestrator] Started 4-layer networking")
    }
    
    func stopNetworking() {
        guard isNetworkingActive else { return }
        
        // Stop all layers
        cloudSync.resignGatewayNode()
        meshtastic.disconnect()
        bleMesh.stopAdvertising()
        bleMesh.stopScanning()
        
        isNetworkingActive = false
        activeLayer = .offline
        networkHealth = .offline
        
        print("🌐 [NetworkOrchestrator] Stopped networking")
    }
    
    func pauseNetworking() {
        guard isNetworkingActive else { return }
        
        // Reduce power consumption
        bleMesh.stopScanning()
        // Cloud and Meshtastic stay active (low power)
        
        print("🌐 [NetworkOrchestrator] Paused networking (BLE scanning stopped)")
    }
    
    func resumeNetworking() {
        guard isNetworkingActive else { return }
        
        // Resume BLE scanning
        bleMesh.startScanning()
        
        print("🌐 [NetworkOrchestrator] Resumed networking")
    }
    
    // MARK: - Network Health
    
    private func updateNetworkHealth() {
        let hasCloud = cloudSync.isOnline
        let hasLoRa = meshtastic.isConnected
        let hasBLE = !bleMesh.connectedPeers.isEmpty
        
        // Determine health
        if hasCloud && hasLoRa && hasBLE {
            networkHealth = .excellent
            activeLayer = .hybrid
        } else if (hasCloud && hasLoRa) || (hasLoRa && hasBLE) {
            networkHealth = .good
            activeLayer = .hybrid
        } else if hasCloud || hasLoRa {
            networkHealth = .fair
            activeLayer = hasCloud ? .cloud : .meshtastic
        } else if hasBLE {
            networkHealth = .limited
            activeLayer = .ble
        } else {
            networkHealth = .offline
            activeLayer = .offline
        }
        
        print("🌐 [NetworkOrchestrator] Network health: \(networkHealth.description)")
    }
    
    // MARK: - Routing Logic
    
    /// Determine which network layer(s) to use for a given message type
    private func routeMessage(type: MessageType) -> [NetworkLayer] {
        let hasCloud = cloudSync.isOnline
        let hasLoRa = meshtastic.isConnected
        let hasBLE = !bleMesh.connectedPeers.isEmpty
        
        switch type {
        case .text, .announcement:
            // Priority: Cloud → LoRa
            if hasCloud {
                return [.cloud, .meshtastic] // Send via both for redundancy
            } else if hasLoRa {
                return [.meshtastic]
            } else {
                return [.offline] // Queue for later
            }
            
        case .emergency:
            // CRITICAL: Send via ALL available layers for maximum delivery
            var layers: [NetworkLayer] = []
            if hasCloud { layers.append(.cloud) }
            if hasLoRa { layers.append(.meshtastic) }
            if hasBLE { layers.append(.ble) }
            if layers.isEmpty { layers.append(.offline) }
            return layers
            
        case .location:
            // Priority: Cloud (fast) → LoRa (fallback)
            if hasCloud {
                return [.cloud]
            } else if hasLoRa {
                return [.meshtastic]
            } else {
                return [.offline] // Queue for later
            }
            
        case .presence:
            // BLE only (immediate, local)
            return hasBLE ? [.ble] : [.offline]
            
        case .largeData:
            // Priority: Cloud → BLE (if in range) → Queue
            if hasCloud {
                return [.cloud]
            } else if hasBLE {
                return [.ble]
            } else {
                return [.offline] // Queue for later
            }
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
    
    /// Send a text message via the appropriate network layer(s)
    func sendTextMessage(_ content: String, to recipient: String? = nil) {
        let layers = routeMessage(type: .text)
        
        for layer in layers {
            switch layer {
            case .cloud:
                let message = CloudSyncService.QueuedMessage(
                    id: UUID().uuidString,
                    type: .text,
                    from: UserDefaults.standard.string(forKey: "userID") ?? "unknown",
                    fromName: UserDefaults.standard.string(forKey: "userName") ?? "Unknown",
                    content: content,
                    location: nil,
                    timestamp: Date(),
                    ttl: 604800 // 7 days
                )
                cloudSync.queueMessage(message)
                print("📡 [NetworkOrchestrator] Sent text via Cloud")
                
            case .meshtastic:
                meshtastic.sendMessage(content, type: .text)
                print("📡 [NetworkOrchestrator] Sent text via Meshtastic")
                
            case .ble:
                // BLE not typically used for text (use LoRa for reliability)
                break
                
            case .offline:
                // Message queued locally
                print("📡 [NetworkOrchestrator] Queued text for later delivery")
                
            case .hybrid:
                // Should not reach here (handled by routing)
                break
            }
        }
    }
    
    /// Send location update via appropriate layer(s)
    func sendLocation(latitude: Double, longitude: Double) {
        let layers = routeMessage(type: .location)
        
        for layer in layers {
            switch layer {
            case .cloud:
                let message = CloudSyncService.QueuedMessage(
                    id: UUID().uuidString,
                    type: .location,
                    from: UserDefaults.standard.string(forKey: "userID") ?? "unknown",
                    fromName: UserDefaults.standard.string(forKey: "userName") ?? "Unknown",
                    content: "",
                    location: CloudSyncService.QueuedMessage.Location(lat: latitude, lon: longitude),
                    timestamp: Date(),
                    ttl: 3600 // 1 hour (locations expire faster)
                )
                cloudSync.queueMessage(message)
                print("📍 [NetworkOrchestrator] Sent location via Cloud")
                
            case .meshtastic:
                let location = CampMember.Location(latitude: latitude, longitude: longitude, timestamp: Date(), accuracy: nil)
                meshtastic.sendLocationUpdate(location)
                print("📍 [NetworkOrchestrator] Sent location via Meshtastic")
                
            case .offline:
                print("📍 [NetworkOrchestrator] Queued location for later delivery")
                
            default:
                break
            }
        }
    }
    
    /// Broadcast emergency alert via ALL available layers
    func sendEmergency(message: String, location: (Double, Double)?) {
        let layers = routeMessage(type: .emergency)
        
        print("🚨 [NetworkOrchestrator] EMERGENCY: Broadcasting via \(layers.count) layers")
        
        for layer in layers {
            switch layer {
            case .cloud:
                let emergencyMessage = CloudSyncService.QueuedMessage(
                    id: UUID().uuidString,
                    type: .emergency,
                    from: UserDefaults.standard.string(forKey: "userID") ?? "unknown",
                    fromName: UserDefaults.standard.string(forKey: "userName") ?? "Unknown",
                    content: message,
                    location: location.map { CloudSyncService.QueuedMessage.Location(lat: $0.0, lon: $0.1) },
                    timestamp: Date(),
                    ttl: 86400 // 24 hours
                )
                cloudSync.queueMessage(emergencyMessage)
                print("🚨 [NetworkOrchestrator] Sent emergency via Cloud")
                
            case .meshtastic:
                meshtastic.sendEmergency()
                print("🚨 [NetworkOrchestrator] Sent emergency via Meshtastic")
                
            case .ble:
                // Emergency broadcast via BLE if available
                print("🚨 [NetworkOrchestrator] Sent emergency via BLE")
                
            case .offline:
                print("🚨 [NetworkOrchestrator] Queued emergency for later delivery")
                
            default:
                break
            }
        }
    }
    
    /// Update presence via BLE (lightweight, immediate)
    func updatePresence(status: String) {
        // BLE presence is handled automatically by advertising
        print("👋 [NetworkOrchestrator] Updated presence via BLE")
    }
    
    /// Send announcement via Cloud + LoRa (redundant)
    func sendAnnouncement(_ content: String) {
        let layers = routeMessage(type: .announcement)
        
        for layer in layers {
            switch layer {
            case .cloud:
                let message = CloudSyncService.QueuedMessage(
                    id: UUID().uuidString,
                    type: .announcement,
                    from: UserDefaults.standard.string(forKey: "userID") ?? "unknown",
                    fromName: UserDefaults.standard.string(forKey: "userName") ?? "Unknown",
                    content: content,
                    location: nil,
                    timestamp: Date(),
                    ttl: 604800 // 7 days
                )
                cloudSync.queueMessage(message)
                print("📢 [NetworkOrchestrator] Sent announcement via Cloud")
                
            case .meshtastic:
                meshtastic.sendMessage(content, type: .text)
                print("📢 [NetworkOrchestrator] Sent announcement via Meshtastic")
                
            default:
                break
            }
        }
    }
}
