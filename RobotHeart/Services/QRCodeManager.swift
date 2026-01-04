import Foundation
import Combine

/// Manager for handling QR code operations and integrating with NetworkOrchestrator.
/// Processes scanned QR codes and coordinates with the mesh network.
@MainActor
class QRCodeManager: ObservableObject {
    
    // MARK: - Dependencies
    
    private let networkOrchestrator: NetworkOrchestrator
    
    // MARK: - Published State
    
    @Published var lastScannedContact: QRContact?
    @Published var lastScannedNode: QRMeshNode?
    @Published var lastScannedInvite: QRCampInvite?
    
    // MARK: - Initialization
    
    init(networkOrchestrator: NetworkOrchestrator) {
        self.networkOrchestrator = networkOrchestrator
    }
    
    // MARK: - Contact Handling
    
    /// Process a scanned contact QR code
    func handleScannedContact(_ contact: QRContact) async throws {
        lastScannedContact = contact
        
        print("📇 [QRCodeManager] Processing contact: \(contact.name)")
        
        // Add to contacts database
        try await addContactToDatabase(contact)
        
        // If they have a Meshtastic node, add it to the network
        if let nodeID = contact.meshtasticNodeID {
            try await addNodeToMeshtastic(nodeID: nodeID, name: contact.name)
        }
        
        // Send a greeting message via mesh
        await sendGreetingMessage(to: contact)
        
        print("✅ [QRCodeManager] Contact added successfully: \(contact.name)")
    }
    
    private func addContactToDatabase(_ contact: QRContact) async throws {
        // TODO: Integrate with your contact database
        // This would typically save to Core Data or similar
        
        // For now, just store in UserDefaults as a simple example
        var contacts = UserDefaults.standard.stringArray(forKey: "contacts") ?? []
        if let jsonData = try? JSONEncoder().encode(contact),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            contacts.append(jsonString)
            UserDefaults.standard.set(contacts, forKey: "contacts")
        }
    }
    
    private func sendGreetingMessage(to contact: QRContact) async {
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Anonymous"
        let message = "👋 Hi \(contact.name)! \(userName) just added you as a contact."
        
        // Send via NetworkOrchestrator
        // This will use the best available network layer
        // networkOrchestrator.sendMessage(message, to: contact.id)
        
        print("💬 [QRCodeManager] Sent greeting to \(contact.name)")
    }
    
    // MARK: - Mesh Node Handling
    
    /// Process a scanned mesh node QR code
    func handleScannedMeshNode(_ node: QRMeshNode) async throws {
        lastScannedNode = node
        
        print("📡 [QRCodeManager] Processing mesh node: \(node.nodeName) (ID: \(node.nodeID))")
        
        // Add node to Meshtastic network
        try await addNodeToMeshtastic(nodeID: node.nodeID, name: node.nodeName)
        
        // Store node info
        try await storeNodeInfo(node)
        
        // Request node info update via mesh
        await requestNodeInfo(node.nodeID)
        
        print("✅ [QRCodeManager] Mesh node added successfully: \(node.nodeName)")
    }
    
    private func addNodeToMeshtastic(nodeID: UInt32, name: String) async throws {
        // TODO: Integrate with MeshtasticManager via NetworkOrchestrator
        // This would add the node to the mesh network's node database
        
        print("📡 [QRCodeManager] Adding node to Meshtastic: \(name) (ID: \(nodeID))")
        
        // Example integration:
        // await networkOrchestrator.meshtastic.addNode(id: nodeID, name: name)
    }
    
    private func storeNodeInfo(_ node: QRMeshNode) async throws {
        // Store node info in local database
        var nodes = UserDefaults.standard.stringArray(forKey: "meshNodes") ?? []
        if let jsonData = try? JSONEncoder().encode(node),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            nodes.append(jsonString)
            UserDefaults.standard.set(nodes, forKey: "meshNodes")
        }
    }
    
    private func requestNodeInfo(_ nodeID: UInt32) async {
        // Request updated node info via mesh network
        // This ensures we have the latest position, battery, etc.
        
        print("📡 [QRCodeManager] Requesting node info for: \(nodeID)")
        
        // Example integration:
        // await networkOrchestrator.meshtastic.requestNodeInfo(nodeID)
    }
    
    // MARK: - Camp Invite Handling
    
    /// Process a scanned camp invite QR code
    func handleScannedCampInvite(_ invite: QRCampInvite) async throws {
        lastScannedInvite = invite
        
        print("🏕️ [QRCodeManager] Processing camp invite: \(invite.campName)")
        
        // Check if invite is expired
        if let expiresAt = invite.expiresAt, expiresAt < Date() {
            throw QRCodeError.inviteExpired
        }
        
        // Join the camp
        try await joinCamp(invite)
        
        // Notify the camp via mesh
        await notifyCampOfJoin(invite)
        
        print("✅ [QRCodeManager] Joined camp successfully: \(invite.campName)")
    }
    
    private func joinCamp(_ invite: QRCampInvite) async throws {
        // Update user's camp affiliation
        UserDefaults.standard.set(invite.campID, forKey: "campID")
        UserDefaults.standard.set(invite.campName, forKey: "campName")
        
        // TODO: Sync with backend if online
        // await networkOrchestrator.cloudSync.syncCampMembership(invite.campID)
    }
    
    private func notifyCampOfJoin(_ invite: QRCampInvite) async {
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Anonymous"
        let message = "🎉 \(userName) has joined \(invite.campName) using invite code \(invite.inviteCode)"
        
        // Send notification to camp channel
        // networkOrchestrator.sendMessage(message, to: invite.campID)
        
        print("💬 [QRCodeManager] Notified camp of join")
    }
    
    // MARK: - QR Code Generation
    
    /// Generate a contact QR code for the current user
    func generateContactQRCode() -> QRContact {
        let userID = UserDefaults.standard.string(forKey: "userID") ?? UUID().uuidString
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Anonymous"
        let userRole = UserDefaults.standard.string(forKey: "userRole")
        let campID = UserDefaults.standard.string(forKey: "campID") ?? "robot-heart"
        
        // TODO: Get actual Meshtastic node ID
        let nodeID: UInt32? = nil // networkOrchestrator.meshtastic.myNodeID
        
        return QRContact(
            id: userID,
            name: userName,
            role: userRole,
            meshtasticNodeID: nodeID,
            campID: campID
        )
    }
    
    /// Generate a mesh node QR code for the current device
    func generateMeshNodeQRCode() -> QRMeshNode? {
        // TODO: Get actual node info from MeshtasticManager
        // let nodeInfo = networkOrchestrator.meshtastic.getMyNodeInfo()
        
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "Anonymous"
        
        return QRMeshNode(
            nodeID: 0x12345678, // Placeholder
            nodeName: "RH-\(userName)",
            hardwareModel: "T1000-E",
            firmwareVersion: "2.3.0",
            publicKey: nil
        )
    }
    
    /// Generate a camp invite QR code
    func generateCampInviteQRCode(expiresInDays: Int = 7) -> QRCampInvite {
        let campID = UserDefaults.standard.string(forKey: "campID") ?? "robot-heart"
        let campName = UserDefaults.standard.string(forKey: "campName") ?? "Robot Heart"
        let inviteCode = generateInviteCode()
        let expiresAt = Calendar.current.date(byAdding: .day, value: expiresInDays, to: Date())
        
        return QRCampInvite(
            campID: campID,
            campName: campName,
            inviteCode: inviteCode,
            expiresAt: expiresAt
        )
    }
    
    private func generateInviteCode() -> String {
        // Generate a random 8-character invite code
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // Excluding ambiguous characters
        return String((0..<8).map { _ in letters.randomElement()! })
    }
}

// MARK: - Errors

enum QRCodeError: Error, LocalizedError {
    case inviteExpired
    case invalidFormat
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .inviteExpired:
            return "This invite has expired"
        case .invalidFormat:
            return "Invalid QR code format"
        case .networkError:
            return "Network error while processing QR code"
        }
    }
}
