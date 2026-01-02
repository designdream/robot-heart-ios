import Foundation
import SwiftUI
import AudioToolbox
import UserNotifications

class EmergencyManager: ObservableObject {
    // MARK: - Published Properties
    @Published var activeEmergency: Emergency?
    @Published var emergencyHistory: [Emergency] = []
    @Published var isSOSActive = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let emergencyHistoryKey = "emergencyHistory"
    private let currentUserID = "!local"
    
    // MARK: - Initialization
    init() {
        loadEmergencyHistory()
    }
    
    // MARK: - Emergency Model
    struct Emergency: Identifiable, Codable, Equatable {
        let id: UUID
        let fromID: String
        let fromName: String
        let message: String
        let location: Location?
        let timestamp: Date
        var acknowledged: Bool
        var acknowledgedBy: [String]
        
        struct Location: Codable, Equatable {
            let latitude: Double
            let longitude: Double
        }
        
        init(
            id: UUID = UUID(),
            fromID: String,
            fromName: String,
            message: String,
            location: Location? = nil,
            timestamp: Date = Date(),
            acknowledged: Bool = false,
            acknowledgedBy: [String] = []
        ) {
            self.id = id
            self.fromID = fromID
            self.fromName = fromName
            self.message = message
            self.location = location
            self.timestamp = timestamp
            self.acknowledged = acknowledged
            self.acknowledgedBy = acknowledgedBy
        }
        
        var isFromMe: Bool {
            fromID == "!local"
        }
        
        var timeAgoText: String {
            let interval = Date().timeIntervalSince(timestamp)
            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                return "\(Int(interval / 60))m ago"
            } else {
                return "\(Int(interval / 3600))h ago"
            }
        }
    }
    
    // MARK: - Send Emergency
    func sendSOS(message: String = "Need assistance at my location", location: (Double, Double)? = nil) {
        let emergency = Emergency(
            fromID: currentUserID,
            fromName: "You",
            message: message,
            location: location.map { Emergency.Location(latitude: $0.0, longitude: $0.1) }
        )
        
        isSOSActive = true
        activeEmergency = emergency
        emergencyHistory.insert(emergency, at: 0)
        saveEmergencyHistory()
        
        // Trigger haptic feedback
        triggerEmergencyHaptics()
        
        // Post notification for mesh broadcast
        NotificationCenter.default.post(
            name: .emergencyBroadcast,
            object: emergency
        )
    }
    
    // MARK: - Receive Emergency
    func receiveEmergency(_ emergency: Emergency) {
        activeEmergency = emergency
        emergencyHistory.insert(emergency, at: 0)
        saveEmergencyHistory()
        
        // Trigger alerts
        triggerEmergencyHaptics()
        playEmergencySound()
        sendEmergencyNotification(emergency)
    }
    
    // MARK: - Acknowledge Emergency
    func acknowledgeEmergency(_ emergency: Emergency) {
        if var active = activeEmergency, active.id == emergency.id {
            active.acknowledged = true
            active.acknowledgedBy.append(currentUserID)
            activeEmergency = nil
            
            // Update history
            if let index = emergencyHistory.firstIndex(where: { $0.id == emergency.id }) {
                emergencyHistory[index] = active
            }
            saveEmergencyHistory()
        }
    }
    
    // MARK: - Cancel My SOS
    func cancelSOS() {
        if let active = activeEmergency, active.isFromMe {
            isSOSActive = false
            activeEmergency = nil
            
            // Broadcast cancellation
            NotificationCenter.default.post(
                name: .emergencyCancelled,
                object: active.id
            )
        }
    }
    
    // MARK: - Clear Active Emergency
    func dismissEmergency() {
        activeEmergency = nil
    }
    
    // MARK: - Haptics & Sound
    private func triggerEmergencyHaptics() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Triple vibration for urgency
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.notificationOccurred(.error)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            generator.notificationOccurred(.error)
        }
    }
    
    private func playEmergencySound() {
        AudioServicesPlaySystemSound(SystemSoundID(1005)) // SMS alert tone
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
    
    // MARK: - Notifications
    private func sendEmergencyNotification(_ emergency: Emergency) {
        let content = UNMutableNotificationContent()
        content.title = "🚨 EMERGENCY ALERT"
        content.body = "\(emergency.fromName): \(emergency.message)"
        content.sound = .defaultCritical
        content.interruptionLevel = .critical
        content.categoryIdentifier = "EMERGENCY"
        
        let request = UNNotificationRequest(
            identifier: "emergency-\(emergency.id.uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Persistence
    private func saveEmergencyHistory() {
        // Keep only last 50 emergencies
        let toSave = Array(emergencyHistory.prefix(50))
        if let encoded = try? JSONEncoder().encode(toSave) {
            userDefaults.set(encoded, forKey: emergencyHistoryKey)
        }
    }
    
    private func loadEmergencyHistory() {
        if let data = userDefaults.data(forKey: emergencyHistoryKey),
           let decoded = try? JSONDecoder().decode([Emergency].self, from: data) {
            emergencyHistory = decoded
        }
    }
    
    // MARK: - Mock Emergency (for testing)
    func simulateIncomingEmergency() {
        let mockEmergency = Emergency(
            fromID: "!e5f6g7h8",
            fromName: "Jordan",
            message: "Lost on deep playa, need pickup",
            location: Emergency.Location(latitude: 40.7870, longitude: -119.2100)
        )
        receiveEmergency(mockEmergency)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let emergencyBroadcast = Notification.Name("emergencyBroadcast")
    static let emergencyCancelled = Notification.Name("emergencyCancelled")
}
