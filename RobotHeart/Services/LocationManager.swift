import Foundation
import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isSharing = false
    @Published var shareInterval: TimeInterval = 900 // 15 minutes default
    @Published var isLocationPrivate = false // Ghost mode - hide location from others
    @Published var shareStatusOnly = false // Share battery/status but not location
    
    // MARK: - Private Properties
    private var locationManager: CLLocationManager?
    private var shareTimer: Timer?
    private var lastSharedLocation: CLLocation?
    private let minimumDistanceChange: CLLocationDistance = 50 // meters
    private var isSetup = false
    
    // MARK: - Initialization
    override init() {
        super.init()
        // Don't setup location manager here - do it lazily to avoid blocking main thread
    }
    
    // MARK: - Setup
    private func setupLocationManager() {
        guard !isSetup else { return }
        isSetup = true
        
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = minimumDistanceChange
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        locationManager = manager
    }
    
    // MARK: - Public Methods
    func requestAuthorization() {
        setupLocationManager()
        locationManager?.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        setupLocationManager()
        locationManager?.startUpdatingLocation()
    }
    
    func stopTracking() {
        locationManager?.stopUpdatingLocation()
    }
    
    func startSharing(interval: TimeInterval = 900) {
        isSharing = true
        shareInterval = interval
        
        // Start location updates
        startTracking()
        
        // Set up periodic sharing
        shareTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.shareCurrentLocation()
        }
        
        // Share immediately
        shareCurrentLocation()
    }
    
    func stopSharing() {
        isSharing = false
        shareTimer?.invalidate()
        shareTimer = nil
    }
    
    func shareCurrentLocation() {
        guard let location = location else { return }
        
        // Don't share location if privacy mode is on
        if isLocationPrivate {
            // Share status-only update (no coordinates)
            NotificationCenter.default.post(
                name: .statusOnlyUpdate,
                object: nil
            )
            return
        }
        
        // Only share if moved significantly or enough time has passed
        if shouldShareLocation(location) {
            let campLocation = CampMember.Location(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timestamp: Date(),
                accuracy: location.horizontalAccuracy
            )
            
            // Send to Meshtastic
            NotificationCenter.default.post(
                name: .locationUpdate,
                object: campLocation
            )
            
            lastSharedLocation = location
        }
    }
    
    // MARK: - Privacy Controls
    func enableGhostMode() {
        isLocationPrivate = true
        UserDefaults.standard.set(true, forKey: "locationPrivate")
    }
    
    func disableGhostMode() {
        isLocationPrivate = false
        UserDefaults.standard.set(false, forKey: "locationPrivate")
    }
    
    func loadPrivacySettings() {
        isLocationPrivate = UserDefaults.standard.bool(forKey: "locationPrivate")
    }
    
    // MARK: - Private Methods
    private func shouldShareLocation(_ location: CLLocation) -> Bool {
        guard let lastLocation = lastSharedLocation else {
            return true
        }
        
        let distance = location.distance(from: lastLocation)
        return distance >= minimumDistanceChange
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.location = location
        
        // If sharing is enabled and location changed significantly, share it
        if isSharing {
            shareCurrentLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startTracking()
        case .denied, .restricted:
            print("Location access denied")
        case .notDetermined:
            requestAuthorization()
        @unknown default:
            break
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let locationUpdate = Notification.Name("locationUpdate")
    static let statusOnlyUpdate = Notification.Name("statusOnlyUpdate")
}
