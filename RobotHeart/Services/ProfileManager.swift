import Foundation
import Combine
import PhotosUI
import SwiftUI

class ProfileManager: ObservableObject {
    // MARK: - Published Properties
    @Published var myProfile: UserProfile
    @Published var campMap: CampMap
    @Published var contactRequests: [ContactRequest] = []
    @Published var approvedContacts: [String] = [] // Member IDs I've approved
    @Published var pendingRequestsCount: Int = 0
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let profileKey = "myProfile"
    private let campMapKey = "campMap"
    private let contactRequestsKey = "contactRequests"
    private let approvedContactsKey = "approvedContacts"
    private let currentUserID = "!local"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // Load or create profile
        if let data = userDefaults.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            myProfile = profile
        } else {
            myProfile = UserProfile(id: currentUserID, displayName: "Burner")
        }
        
        // Load camp map
        if let data = userDefaults.data(forKey: campMapKey),
           let map = try? JSONDecoder().decode(CampMap.self, from: data) {
            campMap = map
        } else {
            campMap = CampMap()
        }
        
        loadContactRequests()
        loadApprovedContacts()
        updatePendingCount()
    }
    
    // MARK: - Profile Updates
    func updateDisplayName(_ name: String) {
        myProfile.displayName = name
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updateRealName(_ name: String?) {
        myProfile.realName = name
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updateHomeLocation(city: String?, country: String?) {
        myProfile.homeCity = city
        myProfile.homeCountry = country
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updateContactInfo(email: String?, phone: String?, instagram: String?, other: String?) {
        myProfile.email = email
        myProfile.phone = phone
        myProfile.instagram = instagram
        myProfile.otherContact = other
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updatePrivacySettings(_ settings: PrivacySettings) {
        myProfile.privacySettings = settings
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updateProfilePhoto(_ imageData: Data?) {
        myProfile.profilePhotoData = imageData
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    func updateCampLocation(_ location: CampLocation?) {
        myProfile.campLocation = location
        myProfile.updatedAt = Date()
        saveProfile()
    }
    
    // MARK: - Contact Requests
    func sendContactRequest(to memberID: String, memberName: String, message: String? = nil) {
        let request = ContactRequest(
            fromMemberID: currentUserID,
            fromDisplayName: myProfile.displayName,
            toMemberID: memberID,
            message: message
        )
        
        // In production, this would be sent via mesh
        NotificationCenter.default.post(
            name: .contactRequestSent,
            object: request
        )
    }
    
    func receiveContactRequest(_ request: ContactRequest) {
        guard request.toMemberID == currentUserID else { return }
        
        // Check if auto-approve is on
        if myProfile.privacySettings.autoApproveContacts {
            var approved = request
            approved.status = .approved
            approved.respondedAt = Date()
            contactRequests.append(approved)
            approvedContacts.append(request.fromMemberID)
        } else {
            contactRequests.append(request)
        }
        
        saveContactRequests()
        saveApprovedContacts()
        updatePendingCount()
    }
    
    func approveContactRequest(_ requestID: UUID) {
        guard let index = contactRequests.firstIndex(where: { $0.id == requestID }) else { return }
        
        contactRequests[index].status = .approved
        contactRequests[index].respondedAt = Date()
        
        let memberID = contactRequests[index].fromMemberID
        if !approvedContacts.contains(memberID) {
            approvedContacts.append(memberID)
        }
        
        saveContactRequests()
        saveApprovedContacts()
        updatePendingCount()
        
        // Notify requester
        NotificationCenter.default.post(
            name: .contactRequestApproved,
            object: contactRequests[index]
        )
    }
    
    func declineContactRequest(_ requestID: UUID) {
        guard let index = contactRequests.firstIndex(where: { $0.id == requestID }) else { return }
        
        contactRequests[index].status = .declined
        contactRequests[index].respondedAt = Date()
        
        saveContactRequests()
        updatePendingCount()
    }
    
    func isContactApproved(_ memberID: String) -> Bool {
        approvedContacts.contains(memberID)
    }
    
    func hasPendingRequest(from memberID: String) -> Bool {
        contactRequests.contains { $0.fromMemberID == memberID && $0.status == .pending }
    }
    
    private func updatePendingCount() {
        pendingRequestsCount = contactRequests.filter { $0.status == .pending }.count
    }
    
    // MARK: - Camp Map Management
    func uploadCampMapImage(_ imageData: Data) {
        campMap.imageData = imageData
        campMap.lastUpdated = Date()
        saveCampMap()
    }
    
    func addStructure(name: String, type: CampMapStructure.StructureType, x: Double, y: Double) -> CampMapStructure {
        let structure = CampMapStructure(name: name, type: type, xPosition: x, yPosition: y)
        campMap.addStructure(structure)
        saveCampMap()
        return structure
    }
    
    func removeStructure(_ id: UUID) {
        campMap.removeStructure(id)
        saveCampMap()
    }
    
    func assignMemberToStructure(_ memberID: String, structureID: UUID) {
        campMap.assignMember(memberID, to: structureID)
        saveCampMap()
    }
    
    func setMyCampLocation(structureID: UUID) {
        guard let structure = campMap.structures.first(where: { $0.id == structureID }) else { return }
        
        let location = CampLocation(
            structureID: structureID.uuidString,
            structureName: structure.name,
            xPosition: structure.xPosition,
            yPosition: structure.yPosition
        )
        
        updateCampLocation(location)
        assignMemberToStructure(currentUserID, structureID: structureID)
    }
    
    // MARK: - Visibility Helpers
    func canSeeRealName(of memberID: String, theirSettings: PrivacySettings) -> Bool {
        switch theirSettings.realNameVisibility {
        case .everyone: return true
        case .approved: return isContactApproved(memberID)
        case .nobody: return false
        }
    }
    
    func canSeeContactInfo(of memberID: String, theirSettings: PrivacySettings) -> Bool {
        switch theirSettings.contactVisibility {
        case .everyone: return true
        case .approved: return isContactApproved(memberID)
        case .nobody: return false
        }
    }
    
    // MARK: - Persistence
    private func saveProfile() {
        if let encoded = try? JSONEncoder().encode(myProfile) {
            userDefaults.set(encoded, forKey: profileKey)
        }
    }
    
    private func saveCampMap() {
        if let encoded = try? JSONEncoder().encode(campMap) {
            userDefaults.set(encoded, forKey: campMapKey)
        }
    }
    
    private func saveContactRequests() {
        if let encoded = try? JSONEncoder().encode(contactRequests) {
            userDefaults.set(encoded, forKey: contactRequestsKey)
        }
    }
    
    private func loadContactRequests() {
        if let data = userDefaults.data(forKey: contactRequestsKey),
           let decoded = try? JSONDecoder().decode([ContactRequest].self, from: data) {
            contactRequests = decoded
        }
    }
    
    private func saveApprovedContacts() {
        userDefaults.set(approvedContacts, forKey: approvedContactsKey)
    }
    
    private func loadApprovedContacts() {
        approvedContacts = userDefaults.stringArray(forKey: approvedContactsKey) ?? []
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let contactRequestSent = Notification.Name("contactRequestSent")
    static let contactRequestApproved = Notification.Name("contactRequestApproved")
}
