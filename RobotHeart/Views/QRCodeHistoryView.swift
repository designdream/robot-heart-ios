import SwiftUI

struct QRCodeHistoryView: View {
    @EnvironmentObject var appEnvironment: AppEnvironment
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedFilter: HistoryFilter = .all
    @State private var showingClearConfirmation = false
    
    enum HistoryFilter: String, CaseIterable {
        case all = "All"
        case contacts = "Contacts"
        case nodes = "Nodes"
        case invites = "Invites"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.5))
                    
                    TextField("Search history...", text: $searchText)
                        .foregroundColor(Color(hex: Theme.Colors.robotCream))
                        .accentColor(Color(hex: Theme.Colors.sunsetOrange))
                }
                .padding()
                .background(Color(hex: Theme.Colors.deepNight))
                .cornerRadius(12)
                .padding()
                
                // Filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HistoryFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: { selectedFilter = filter }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
                
                // History list
                if filteredHistory.isEmpty {
                    EmptyHistoryView(filter: selectedFilter)
                } else {
                    List {
                        ForEach(filteredHistory) { item in
                            HistoryItemRow(item: item)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteHistoryItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        toggleFavorite(item)
                                    } label: {
                                        Label(
                                            item.isFavorite ? "Unfavorite" : "Favorite",
                                            systemImage: item.isFavorite ? "star.slash" : "star.fill"
                                        )
                                    }
                                    .tint(Color(hex: Theme.Colors.goldenYellow))
                                }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(hex: Theme.Colors.blackPlaya))
            .navigationTitle("QR History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: Theme.Colors.sunsetOrange))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Color(hex: Theme.Colors.sunsetOrange))
                    }
                    .disabled(qrHistory.isEmpty)
                }
            }
            .alert("Clear History?", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    clearHistory()
                }
            } message: {
                Text("This will permanently delete all QR code scan history.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var qrHistory: [QRHistoryItem] {
        // TODO: Load from persistent storage
        // For now, return demo data
        return [
            QRHistoryItem(
                id: UUID().uuidString,
                type: .contact,
                title: "Felipe",
                subtitle: "Camp Lead • Node 12345",
                timestamp: Date().addingTimeInterval(-300),
                isFavorite: true
            ),
            QRHistoryItem(
                id: UUID().uuidString,
                type: .node,
                title: "T1000-E Device",
                subtitle: "Node 67890 • Firmware 2.3.1",
                timestamp: Date().addingTimeInterval(-1800),
                isFavorite: false
            ),
            QRHistoryItem(
                id: UUID().uuidString,
                type: .invite,
                title: "Robot Heart Camp",
                subtitle: "Expires in 7 days",
                timestamp: Date().addingTimeInterval(-3600),
                isFavorite: false
            ),
            QRHistoryItem(
                id: UUID().uuidString,
                type: .contact,
                title: "DJ Sparkle",
                subtitle: "Bus DJ • Node 11111",
                timestamp: Date().addingTimeInterval(-7200),
                isFavorite: true
            )
        ]
    }
    
    private var filteredHistory: [QRHistoryItem] {
        var items = qrHistory
        
        // Apply filter
        switch selectedFilter {
        case .all:
            break
        case .contacts:
            items = items.filter { $0.type == .contact }
        case .nodes:
            items = items.filter { $0.type == .node }
        case .invites:
            items = items.filter { $0.type == .invite }
        }
        
        // Apply search
        if !searchText.isEmpty {
            items = items.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.subtitle.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return items
    }
    
    // MARK: - Actions
    
    private func deleteHistoryItem(_ item: QRHistoryItem) {
        // TODO: Implement deletion from persistent storage
        print("🗑️ Delete history item: \(item.title)")
    }
    
    private func toggleFavorite(_ item: QRHistoryItem) {
        // TODO: Implement favorite toggle in persistent storage
        print("⭐️ Toggle favorite: \(item.title)")
    }
    
    private func clearHistory() {
        // TODO: Implement clear all from persistent storage
        print("🗑️ Clear all history")
    }
}

// MARK: - Supporting Views

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? Color(hex: Theme.Colors.blackPlaya) : Color(hex: Theme.Colors.robotCream))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: Theme.Colors.sunsetOrange) : Color(hex: Theme.Colors.deepNight))
                .cornerRadius(20)
        }
    }
}

struct HistoryItemRow: View {
    let item: QRHistoryItem
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: Theme.Colors.deepNight))
                    .frame(width: 48, height: 48)
                
                Image(systemName: item.type.icon)
                    .font(.title3)
                    .foregroundColor(Color(hex: item.type.color))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(Color(hex: Theme.Colors.robotCream))
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(Color(hex: Theme.Colors.goldenYellow))
                    }
                }
                
                Text(item.subtitle)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.7))
                
                Text(item.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.5))
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.3))
        }
        .padding()
        .background(Color(hex: Theme.Colors.deepNight))
        .cornerRadius(12)
    }
}

struct EmptyHistoryView: View {
    let filter: QRCodeHistoryView.HistoryFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.3))
            
            Text("No \(filter.rawValue) History")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: Theme.Colors.robotCream))
            
            Text("Scan QR codes to see them here")
                .font(.subheadline)
                .foregroundColor(Color(hex: Theme.Colors.robotCream).opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Data Models

struct QRHistoryItem: Identifiable {
    let id: String
    let type: QRType
    let title: String
    let subtitle: String
    let timestamp: Date
    var isFavorite: Bool
    
    enum QRType {
        case contact
        case node
        case invite
        
        var icon: String {
            switch self {
            case .contact: return "person.circle.fill"
            case .node: return "antenna.radiowaves.left.and.right"
            case .invite: return "envelope.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .contact: return Theme.Colors.turquoiseSky
            case .node: return Theme.Colors.sunsetOrange
            case .invite: return Theme.Colors.goldenYellow
            }
        }
    }
}

// MARK: - Preview

#Preview {
    QRCodeHistoryView()
        .environmentObject(AppEnvironment())
}
