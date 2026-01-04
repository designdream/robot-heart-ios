import Foundation
import CoreLocation
import Combine

/// Service responsible for handling Meshtastic location sharing.
/// Manages location packet handling, sharing status, and update frequency.
@MainActor
class MeshtasticLocationService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isLocationSharingEnabled: Bool = false
    @Published var locationUpdateInterval: TimeInterval = 300 // 5 minutes default
    @Published var lastLocationSent: Date?
    @Published var nodeLocations: [UInt32: CLLocation] = [:]
    
    // MARK: - Private Properties
    
    private let protocolService = MeshtasticProtocolService.shared
    private var locationUpdateTimer: Timer?
    private var lastSentLocation: CLLocation?
    private let minimumDistanceThreshold: CLLocationDistance = 50 // meters
    private let userDefaults = UserDefaults.standard
    private let locationSharingKey = "meshtastic_location_sharing_enabled"
    private let locationIntervalKey = "meshtastic_location_interval"
    
    // Callbacks
    var sendData: ((Data) throws -> Void)?
    var getCurrentLocation: (() -> CLLocation?)?
    var onLocationReceived: ((UInt32, CLLocation) -> Void)?
    
    // MARK: - Initialization
    
    init() {
        loadSettings()
    }
    
    deinit {
        stopLocationSharing()
    }
    
    // MARK: - Public Methods
    
    /// Enable location sharing
    func startLocationSharing() {
        guard !isLocationSharingEnabled else { return }
        
        isLocationSharingEnabled = true
        userDefaults.set(true, forKey: locationSharingKey)
        
        // Send initial location immediately
        sendLocationUpdate()
        
        // Schedule periodic updates
        scheduleLocationUpdates()
        
        print("📍 [MeshtasticLocation] Started location sharing (interval: \(locationUpdateInterval)s)")
    }
    
    /// Disable location sharing
    func stopLocationSharing() {
        guard isLocationSharingEnabled else { return }
        
        isLocationSharingEnabled = false
        userDefaults.set(false, forKey: locationSharingKey)
        
        // Cancel timer
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
        
        print("📍 [MeshtasticLocation] Stopped location sharing")
    }
    
    /// Set location update interval
    func setUpdateInterval(_ interval: TimeInterval) {
        locationUpdateInterval = max(60, interval) // Minimum 1 minute
        userDefaults.set(locationUpdateInterval, forKey: locationIntervalKey)
        
        // Restart timer with new interval
        if isLocationSharingEnabled {
            scheduleLocationUpdates()
        }
        
        print("📍 [MeshtasticLocation] Set update interval to \(locationUpdateInterval)s")
    }
    
    /// Manually send location update
    func sendLocationUpdate() {
        guard let location = getCurrentLocation?() else {
            print("⚠️ [MeshtasticLocation] No location available")
            return
        }
        
        // Check if we've moved enough to warrant an update
        if let lastLocation = lastSentLocation {
            let distance = location.distance(from: lastLocation)
            if distance < minimumDistanceThreshold {
                print("📍 [MeshtasticLocation] Skipping update (moved only \(Int(distance))m)")
                return
            }
        }
        
        do {
            // Encode location packet
            let packet = try protocolService.encodePosition(location)
            
            // Send via connection service
            try sendData?(packet)
            
            // Update state
            lastSentLocation = location
            lastLocationSent = Date()
            
            print("📍 [MeshtasticLocation] Sent location: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
        } catch {
            print("❌ [MeshtasticLocation] Failed to send location: \(error.localizedDescription)")
        }
    }
    
    /// Process received location packet
    func processReceivedPacket(_ packet: MeshtasticPacket) {
        guard packet.portNum == .position else { return }
        
        do {
            // Decode location
            let location = try protocolService.decodePosition(from: packet.payload)
            
            // Store location
            nodeLocations[packet.fromNodeID] = location
            
            // Notify callback
            onLocationReceived?(packet.fromNodeID, location)
            
            print("📍 [MeshtasticLocation] Received location from node \(packet.fromNodeID): \(location.coordinate.latitude), \(location.coordinate.longitude)")
            
        } catch {
            print("❌ [MeshtasticLocation] Failed to decode location: \(error.localizedDescription)")
        }
    }
    
    /// Get location for a specific node
    func getLocation(for nodeID: UInt32) -> CLLocation? {
        return nodeLocations[nodeID]
    }
    
    /// Get all node locations
    func getAllLocations() -> [UInt32: CLLocation] {
        return nodeLocations
    }
    
    /// Clear location for a node
    func clearLocation(for nodeID: UInt32) {
        nodeLocations.removeValue(forKey: nodeID)
    }
    
    /// Clear all locations
    func clearAllLocations() {
        nodeLocations.removeAll()
        print("📍 [MeshtasticLocation] Cleared all node locations")
    }
    
    /// Get sharing status summary
    func getSharingStatus() -> LocationSharingStatus {
        return LocationSharingStatus(
            isEnabled: isLocationSharingEnabled,
            updateInterval: locationUpdateInterval,
            lastSent: lastLocationSent,
            trackedNodes: nodeLocations.count
        )
    }
    
    // MARK: - Private Methods
    
    private func scheduleLocationUpdates() {
        // Cancel existing timer
        locationUpdateTimer?.invalidate()
        
        // Create new timer
        locationUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: locationUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.sendLocationUpdate()
            }
        }
    }
    
    private func loadSettings() {
        isLocationSharingEnabled = userDefaults.bool(forKey: locationSharingKey)
        
        let savedInterval = userDefaults.double(forKey: locationIntervalKey)
        if savedInterval > 0 {
            locationUpdateInterval = savedInterval
        }
        
        // Resume location sharing if it was enabled
        if isLocationSharingEnabled {
            scheduleLocationUpdates()
        }
        
        print("📍 [MeshtasticLocation] Loaded settings: sharing=\(isLocationSharingEnabled), interval=\(locationUpdateInterval)s")
    }
}

// MARK: - Supporting Types

struct LocationSharingStatus {
    let isEnabled: Bool
    let updateInterval: TimeInterval
    let lastSent: Date?
    let trackedNodes: Int
    
    var updateIntervalDescription: String {
        let minutes = Int(updateInterval / 60)
        if minutes < 60 {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        } else {
            let hours = minutes / 60
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }
    
    var lastSentDescription: String {
        guard let lastSent = lastSent else { return "Never" }
        
        let interval = Date().timeIntervalSince(lastSent)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - Location Update Intervals

extension MeshtasticLocationService {
    /// Predefined update intervals
    enum UpdateInterval: TimeInterval, CaseIterable {
        case oneMinute = 60
        case fiveMinutes = 300
        case tenMinutes = 600
        case thirtyMinutes = 1800
        case oneHour = 3600
        case twoHours = 7200
        
        var description: String {
            switch self {
            case .oneMinute: return "1 minute"
            case .fiveMinutes: return "5 minutes"
            case .tenMinutes: return "10 minutes"
            case .thirtyMinutes: return "30 minutes"
            case .oneHour: return "1 hour"
            case .twoHours: return "2 hours"
            }
        }
        
        var icon: String {
            switch self {
            case .oneMinute: return "⚡️"
            case .fiveMinutes: return "🔥"
            case .tenMinutes: return "⏱️"
            case .thirtyMinutes: return "⏰"
            case .oneHour: return "🕐"
            case .twoHours: return "🌙"
            }
        }
        
        var batteryImpact: String {
            switch self {
            case .oneMinute: return "High battery usage"
            case .fiveMinutes: return "Moderate battery usage"
            case .tenMinutes: return "Balanced"
            case .thirtyMinutes: return "Low battery usage"
            case .oneHour: return "Very low battery usage"
            case .twoHours: return "Minimal battery usage"
            }
        }
    }
}
