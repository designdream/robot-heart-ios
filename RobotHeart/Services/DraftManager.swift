import Foundation
import Combine
import UserNotifications

class DraftManager: ObservableObject {
    // MARK: - Published Properties
    @Published var activeDraft: ShiftDraft?
    @Published var upcomingDrafts: [ShiftDraft] = []
    @Published var completedDrafts: [ShiftDraft] = []
    @Published var draftEvents: [DraftEvent] = []
    @Published var pickTimer: TimeInterval = 0
    @Published var isMyTurn: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let draftsKey = "shiftDrafts"
    private let currentUserID = "!local"
    private var pickTimerCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadDrafts()
    }
    
    // MARK: - Admin: Create Draft
    func createDraft(name: String, scheduledStart: Date?, settings: DraftSettings = DraftSettings()) -> ShiftDraft {
        var draft = ShiftDraft(
            name: name,
            createdBy: currentUserID,
            scheduledStart: scheduledStart,
            settings: settings
        )
        
        upcomingDrafts.append(draft)
        saveDrafts()
        
        return draft
    }
    
    // MARK: - Admin: Add Shifts to Draft
    func addShiftToDraft(_ draftID: UUID, shift: DraftableShift) {
        if var draft = findDraft(draftID) {
            draft.availableShifts.append(shift)
            updateDraft(draft)
        }
    }
    
    func addShiftsToDraft(_ draftID: UUID, shifts: [DraftableShift]) {
        if var draft = findDraft(draftID) {
            draft.availableShifts.append(contentsOf: shifts)
            updateDraft(draft)
        }
    }
    
    func removeShiftFromDraft(_ draftID: UUID, shiftID: UUID) {
        if var draft = findDraft(draftID) {
            draft.availableShifts.removeAll { $0.id == shiftID }
            updateDraft(draft)
        }
    }
    
    // MARK: - Admin: Set Participants
    func setParticipants(_ draftID: UUID, memberIDs: [String]) {
        if var draft = findDraft(draftID) {
            if draft.settings.randomizeOrder {
                draft.pickOrder = memberIDs.shuffled()
            } else {
                draft.pickOrder = memberIDs
            }
            updateDraft(draft)
        }
    }
    
    // MARK: - Admin: Start Draft
    func startDraft(_ draftID: UUID) {
        guard var draft = findDraft(draftID) else { return }
        guard draft.status == .setup || draft.status == .scheduled else { return }
        guard !draft.availableShifts.isEmpty else { return }
        guard !draft.pickOrder.isEmpty else { return }
        
        draft.status = .active
        draft.actualStart = Date()
        draft.currentRound = 1
        draft.currentPickIndex = 0
        
        updateDraft(draft)
        activeDraft = draft
        
        // Add event
        addEvent(draftID: draftID, type: .draftStarted, message: "Draft has begun!")
        
        // Start pick timer
        startPickTimer()
        
        // Check if it's my turn
        checkMyTurn()
        
        // Notify participants
        notifyDraftStarted(draft)
    }
    
    // MARK: - Admin: Pause/Resume Draft
    func pauseDraft(_ draftID: UUID) {
        guard var draft = findDraft(draftID), draft.status == .active else { return }
        
        draft.status = .paused
        updateDraft(draft)
        activeDraft = draft
        
        stopPickTimer()
        addEvent(draftID: draftID, type: .draftPaused, message: "Draft paused")
    }
    
    func resumeDraft(_ draftID: UUID) {
        guard var draft = findDraft(draftID), draft.status == .paused else { return }
        
        draft.status = .active
        updateDraft(draft)
        activeDraft = draft
        
        startPickTimer()
        addEvent(draftID: draftID, type: .draftResumed, message: "Draft resumed")
    }
    
    // MARK: - Member: Make Pick
    func makePick(shiftID: UUID) {
        guard var draft = activeDraft, draft.status == .active else { return }
        guard draft.currentPicker == currentUserID else { return }
        guard draft.remainingShifts.contains(where: { $0.id == shiftID }) else { return }
        
        let pick = DraftPick(
            draftID: draft.id,
            round: draft.currentRound,
            pickNumber: draft.picksMade + 1,
            memberID: currentUserID,
            memberName: "You",
            shiftID: shiftID
        )
        
        draft.picks.append(pick)
        
        // Get shift name for event
        let shiftName = draft.availableShifts.first { $0.id == shiftID }?.location.rawValue ?? "Shift"
        addEvent(draftID: draft.id, type: .pickMade, memberID: currentUserID, message: "You picked \(shiftName)")
        
        // Advance to next pick
        advanceDraft(&draft)
        
        updateDraft(draft)
        activeDraft = draft
        
        // Reset timer for next picker
        startPickTimer()
        checkMyTurn()
    }
    
    // MARK: - Auto Pick (when timer expires)
    private func autoPick() {
        guard var draft = activeDraft, draft.status == .active else { return }
        guard let currentPicker = draft.currentPicker else { return }
        
        // Pick highest point value remaining shift
        guard let bestShift = draft.remainingShifts.max(by: { $0.pointValue < $1.pointValue }) else { return }
        
        let pick = DraftPick(
            draftID: draft.id,
            round: draft.currentRound,
            pickNumber: draft.picksMade + 1,
            memberID: currentPicker,
            memberName: currentPicker == currentUserID ? "You" : "Participant",
            shiftID: bestShift.id,
            wasAutoPick: true
        )
        
        draft.picks.append(pick)
        
        addEvent(draftID: draft.id, type: .autoPick, memberID: currentPicker, 
                 message: "Auto-picked \(bestShift.location.rawValue) (time expired)")
        
        advanceDraft(&draft)
        
        updateDraft(draft)
        activeDraft = draft
        
        startPickTimer()
        checkMyTurn()
    }
    
    // MARK: - Draft Advancement
    private func advanceDraft(_ draft: inout ShiftDraft) {
        draft.currentPickIndex += 1
        
        // Check if round complete
        if draft.currentPickIndex >= draft.pickOrder.count {
            draft.currentPickIndex = 0
            draft.currentRound += 1
            
            addEvent(draftID: draft.id, type: .roundComplete, 
                     message: "Round \(draft.currentRound - 1) complete")
            
            // Check if draft complete
            if draft.currentRound > draft.settings.roundsPerParticipant {
                completeDraft(&draft)
            }
        }
    }
    
    private func completeDraft(_ draft: inout ShiftDraft) {
        draft.status = .completed
        draft.completedAt = Date()
        
        stopPickTimer()
        
        addEvent(draftID: draft.id, type: .draftComplete, message: "Draft complete!")
        
        // Move to completed
        upcomingDrafts.removeAll { $0.id == draft.id }
        completedDrafts.append(draft)
        activeDraft = nil
        
        // Convert picks to actual shifts
        convertPicksToShifts(draft)
        
        saveDrafts()
    }
    
    // MARK: - Convert Picks to Shifts
    private func convertPicksToShifts(_ draft: ShiftDraft) {
        // Post notification to ShiftManager to create actual shifts
        NotificationCenter.default.post(
            name: .draftCompleted,
            object: draft
        )
    }
    
    // MARK: - Timer Management
    private func startPickTimer() {
        guard let draft = activeDraft else { return }
        
        pickTimer = draft.settings.secondsPerPick
        
        pickTimerCancellable?.cancel()
        pickTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if self.pickTimer > 0 {
                    self.pickTimer -= 1
                } else {
                    // Time's up - auto pick
                    if self.activeDraft?.settings.autoPick == true {
                        self.autoPick()
                    }
                }
            }
    }
    
    private func stopPickTimer() {
        pickTimerCancellable?.cancel()
        pickTimerCancellable = nil
        pickTimer = 0
    }
    
    private func checkMyTurn() {
        isMyTurn = activeDraft?.currentPicker == currentUserID
        
        if isMyTurn {
            // Notify user it's their turn
            notifyMyTurn()
        }
    }
    
    // MARK: - Notifications
    private func notifyDraftStarted(_ draft: ShiftDraft) {
        let content = UNMutableNotificationContent()
        content.title = "🏈 Draft Started!"
        content.body = "\(draft.name) is now live. Get ready to pick your shifts!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "draft-started-\(draft.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func notifyMyTurn() {
        let content = UNMutableNotificationContent()
        content.title = "⏰ Your Pick!"
        content.body = "It's your turn to pick a shift. You have \(Int(activeDraft?.settings.secondsPerPick ?? 60)) seconds!"
        content.sound = .defaultCritical
        
        let request = UNNotificationRequest(
            identifier: "draft-myturn-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Events
    private func addEvent(draftID: UUID, type: DraftEvent.EventType, memberID: String? = nil, message: String) {
        let event = DraftEvent(
            id: UUID(),
            draftID: draftID,
            type: type,
            timestamp: Date(),
            memberID: memberID,
            message: message
        )
        
        draftEvents.insert(event, at: 0)
        
        // Keep only last 100 events
        if draftEvents.count > 100 {
            draftEvents = Array(draftEvents.prefix(100))
        }
    }
    
    // MARK: - Queries
    func findDraft(_ id: UUID) -> ShiftDraft? {
        if activeDraft?.id == id { return activeDraft }
        if let draft = upcomingDrafts.first(where: { $0.id == id }) { return draft }
        if let draft = completedDrafts.first(where: { $0.id == id }) { return draft }
        return nil
    }
    
    func myPicksInDraft(_ draftID: UUID) -> [DraftableShift] {
        guard let draft = findDraft(draftID) else { return [] }
        return draft.shiftsPickedBy(currentUserID)
    }
    
    func myPointsInDraft(_ draftID: UUID) -> Int {
        guard let draft = findDraft(draftID) else { return 0 }
        return draft.pointsEarnedBy(currentUserID)
    }
    
    // MARK: - Persistence
    private func updateDraft(_ draft: ShiftDraft) {
        if let index = upcomingDrafts.firstIndex(where: { $0.id == draft.id }) {
            upcomingDrafts[index] = draft
        }
        if activeDraft?.id == draft.id {
            activeDraft = draft
        }
        saveDrafts()
    }
    
    private func saveDrafts() {
        let allDrafts = upcomingDrafts + completedDrafts
        if let encoded = try? JSONEncoder().encode(allDrafts) {
            userDefaults.set(encoded, forKey: draftsKey)
        }
    }
    
    private func loadDrafts() {
        if let data = userDefaults.data(forKey: draftsKey),
           let decoded = try? JSONDecoder().decode([ShiftDraft].self, from: data) {
            upcomingDrafts = decoded.filter { $0.status != .completed && $0.status != .cancelled }
            completedDrafts = decoded.filter { $0.status == .completed }
            
            // Check for active draft
            activeDraft = decoded.first { $0.status == .active }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let draftCompleted = Notification.Name("draftCompleted")
}
