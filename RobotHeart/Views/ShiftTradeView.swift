import SwiftUI

// MARK: - Shift Trade Request View
struct ShiftTradeRequestView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    let shift: Shift
    
    @State private var selectedMember: CampMember?
    @State private var message: String = ""
    @State private var searchText: String = ""
    
    var filteredMembers: [CampMember] {
        let members = meshtasticManager.campMembers.filter { $0.id != "!local" }
        if searchText.isEmpty {
            return members
        }
        return members.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Shift details
                    ShiftTradeHeader(shift: shift)
                    
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        TextField("Search members...", text: $searchText)
                            .foregroundColor(Theme.Colors.robotCream)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    
                    // Member list
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(filteredMembers) { member in
                                MemberSelectRow(
                                    member: member,
                                    isSelected: selectedMember?.id == member.id,
                                    onSelect: { selectedMember = member }
                                )
                            }
                        }
                        .padding()
                    }
                    
                    // Message input
                    VStack(spacing: Theme.Spacing.sm) {
                        TextField("Add a message (optional)", text: $message)
                            .foregroundColor(Theme.Colors.robotCream)
                            .padding()
                            .background(Theme.Colors.backgroundMedium)
                            .cornerRadius(Theme.CornerRadius.md)
                        
                        // Send button
                        Button(action: sendTradeRequest) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Request Trade")
                            }
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedMember != nil ? Theme.Colors.sunsetOrange : Theme.Colors.backgroundLight)
                            .cornerRadius(Theme.CornerRadius.md)
                        }
                        .disabled(selectedMember == nil)
                    }
                    .padding()
                    .background(Theme.Colors.backgroundDark)
                }
            }
            .navigationTitle("Trade Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
    
    private func sendTradeRequest() {
        guard let member = selectedMember else { return }
        shiftManager.requestTrade(
            shift: shift,
            to: member,
            message: message.isEmpty ? nil : message
        )
        dismiss()
    }
}

// MARK: - Shift Trade Header
struct ShiftTradeHeader: View {
    let shift: Shift
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: shift.location.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                VStack(alignment: .leading) {
                    Text(shift.location.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(formatDateTime(shift.startTime))
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Spacer()
                
                Text(shift.durationText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Member Select Row
struct MemberSelectRow: View {
    let member: CampMember
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.backgroundLight)
                        .frame(width: 40, height: 40)
                    
                    Text(member.name.prefix(1))
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(member.name)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: member.role.icon)
                            .font(.caption2)
                        Text(member.role.rawValue)
                            .font(Theme.Typography.caption)
                    }
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            .padding(Theme.Spacing.md)
            .background(isSelected ? Theme.Colors.backgroundLight : Theme.Colors.backgroundMedium)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - Trade Requests List View
struct TradeRequestsListView: View {
    @EnvironmentObject var shiftManager: ShiftManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !shiftManager.tradesNeedingMyAction.isEmpty {
                Text("Needs Your Action")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                ForEach(shiftManager.tradesNeedingMyAction) { trade in
                    TradeRequestCard(trade: trade, needsAction: true)
                }
            }
            
            if !shiftManager.myPendingTrades.isEmpty {
                Text("Pending Trades")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                
                ForEach(shiftManager.myPendingTrades) { trade in
                    TradeRequestCard(trade: trade, needsAction: false)
                }
            }
            
            if shiftManager.tradesNeedingMyAction.isEmpty && shiftManager.myPendingTrades.isEmpty {
                Text("No pending trade requests")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    .padding()
            }
        }
    }
}

// MARK: - Trade Request Card
struct TradeRequestCard: View {
    @EnvironmentObject var shiftManager: ShiftManager
    let trade: ShiftTrade
    let needsAction: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                Text(trade.requestedByName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                Text(trade.offeredToName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                StatusBadge(status: trade.status)
            }
            
            // Shift details
            HStack {
                Text(trade.shiftDetails.location)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                
                Spacer()
                
                Text(formatTime(trade.shiftDetails.startTime))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            // Message if present
            if let message = trade.message {
                Text("\"\(message)\"")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    .italic()
            }
            
            // Approval status
            HStack(spacing: Theme.Spacing.md) {
                ApprovalIndicator(label: trade.requestedByName, approved: trade.requesterApproved)
                ApprovalIndicator(label: trade.offeredToName, approved: trade.receiverApproved)
                ApprovalIndicator(label: "Lead", approved: trade.leadApproved)
            }
            
            // Action buttons
            if needsAction {
                HStack(spacing: Theme.Spacing.md) {
                    Button(action: { shiftManager.rejectTrade(trade) }) {
                        Text("Decline")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.emergency)
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.backgroundLight)
                            .cornerRadius(Theme.CornerRadius.sm)
                    }
                    
                    Button(action: { shiftManager.acceptTrade(trade) }) {
                        Text("Approve")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .frame(maxWidth: .infinity)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.Colors.connected)
                            .cornerRadius(Theme.CornerRadius.sm)
                    }
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                .stroke(needsAction ? Theme.Colors.sunsetOrange : Color.clear, lineWidth: 1)
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: ShiftTrade.TradeStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption2)
            Text(status.rawValue)
                .font(Theme.Typography.caption)
        }
        .foregroundColor(statusColor)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, 2)
        .background(statusColor.opacity(0.2))
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private var statusColor: Color {
        switch status {
        case .pending: return Theme.Colors.warning
        case .awaitingLeadApproval: return Theme.Colors.sunsetOrange
        case .approved: return Theme.Colors.connected
        case .rejected, .cancelled, .expired: return Theme.Colors.disconnected
        }
    }
}

// MARK: - Approval Indicator
struct ApprovalIndicator: View {
    let label: String
    let approved: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: approved ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(approved ? Theme.Colors.connected : Theme.Colors.robotCream.opacity(0.3))
            
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
    }
}

#Preview {
    TradeRequestsListView()
        .padding()
        .background(Theme.Colors.backgroundDark)
        .environmentObject(ShiftManager())
}
