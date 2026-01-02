import Foundation

struct ShiftTrade: Identifiable, Codable, Equatable {
    let id: UUID
    let shiftID: UUID
    let shiftDetails: ShiftDetails
    let requestedBy: String      // Member ID who wants to trade
    let requestedByName: String
    let offeredTo: String        // Member ID who would take the shift
    let offeredToName: String
    let requestedAt: Date
    var status: TradeStatus
    var requesterApproved: Bool  // Person giving up shift approved
    var receiverApproved: Bool   // Person taking shift approved
    var leadApproved: Bool       // Lead/admin approved
    var leadApprovedBy: String?  // Which lead approved
    var completedAt: Date?
    var message: String?         // Optional message with trade request
    
    struct ShiftDetails: Codable, Equatable {
        let location: String
        let startTime: Date
        let endTime: Date
    }
    
    enum TradeStatus: String, Codable {
        case pending = "Pending"
        case awaitingLeadApproval = "Awaiting Lead"
        case approved = "Approved"
        case rejected = "Rejected"
        case cancelled = "Cancelled"
        case expired = "Expired"
        
        var icon: String {
            switch self {
            case .pending: return "clock"
            case .awaitingLeadApproval: return "person.badge.clock"
            case .approved: return "checkmark.circle.fill"
            case .rejected: return "xmark.circle.fill"
            case .cancelled: return "xmark"
            case .expired: return "clock.badge.xmark"
            }
        }
        
        var color: String {
            switch self {
            case .pending: return "warning"
            case .awaitingLeadApproval: return "sunsetOrange"
            case .approved: return "connected"
            case .rejected, .cancelled, .expired: return "disconnected"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        shiftID: UUID,
        shiftDetails: ShiftDetails,
        requestedBy: String,
        requestedByName: String,
        offeredTo: String,
        offeredToName: String,
        requestedAt: Date = Date(),
        status: TradeStatus = .pending,
        requesterApproved: Bool = true, // Requester auto-approves by initiating
        receiverApproved: Bool = false,
        leadApproved: Bool = false,
        leadApprovedBy: String? = nil,
        completedAt: Date? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.shiftID = shiftID
        self.shiftDetails = shiftDetails
        self.requestedBy = requestedBy
        self.requestedByName = requestedByName
        self.offeredTo = offeredTo
        self.offeredToName = offeredToName
        self.requestedAt = requestedAt
        self.status = status
        self.requesterApproved = requesterApproved
        self.receiverApproved = receiverApproved
        self.leadApproved = leadApproved
        self.leadApprovedBy = leadApprovedBy
        self.completedAt = completedAt
        self.message = message
    }
    
    var isFullyApproved: Bool {
        requesterApproved && receiverApproved && leadApproved
    }
    
    var pendingApprovals: [String] {
        var pending: [String] = []
        if !receiverApproved { pending.append(offeredToName) }
        if !leadApproved { pending.append("Lead") }
        return pending
    }
    
    var timeAgoText: String {
        let interval = Date().timeIntervalSince(requestedAt)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h ago"
        } else {
            return "\(Int(interval / 86400))d ago"
        }
    }
}
