import SwiftUI

// MARK: - Camp Browser View
/// View-only camp browser with search - editing requires admin permissions
/// Accessible from My Burn tab
struct CampBrowserView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @EnvironmentObject var shiftManager: ShiftManager
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var showingEditMode = false
    @State private var selectedItem: PlaceableItem?
    
    // Admin check - uses ShiftManager's isAdmin (stored in UserDefaults)
    // In offline-first app, admin status is set locally and synced via mesh
    var isAdmin: Bool {
        shiftManager.isAdmin
    }
    
    var filteredItems: [PlaceableItem] {
        guard let layout = layoutManager.currentLayout else { return [] }
        if searchText.isEmpty {
            return layout.items
        }
        return layout.items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            item.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
            (item.assignedName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                if let layout = layoutManager.currentLayout {
                    VStack(spacing: 0) {
                        // Search bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            
                            TextField("Search camp items, people...", text: $searchText)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                }
                            }
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        
                        // Camp stats
                        CampStatsHeader(layout: layout)
                        
                        // Map view (read-only)
                        CampMapPreview(
                            layout: layout,
                            searchText: searchText,
                            selectedItem: $selectedItem
                        )
                        
                        // Search results list (when searching)
                        if !searchText.isEmpty {
                            SearchResultsList(
                                items: filteredItems,
                                selectedItem: $selectedItem
                            )
                        }
                        
                        // Selected item detail
                        if let item = selectedItem {
                            SelectedItemCard(item: item) {
                                selectedItem = nil
                            }
                        }
                    }
                } else {
                    NoCampLayoutView()
                }
            }
            .navigationTitle("Camp Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isAdmin {
                        Button(action: { showingEditMode = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("Edit")
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditMode) {
                CampLayoutPlannerView()
            }
        }
    }
}

// MARK: - Camp Stats Header
struct CampStatsHeader: View {
    let layout: CampLayout
    
    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            CampStatItem(
                value: "\(Int(layout.grid.widthFeet))×\(Int(layout.grid.depthFeet))'",
                label: "Size"
            )
            
            CampStatItem(
                value: "\(layout.items.count)",
                label: "Items"
            )
            
            CampStatItem(
                value: "\(layout.items.filter { $0.assignedTo != nil }.count)",
                label: "Assigned"
            )
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
    }
}

struct CampStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.robotCream)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camp Map Preview (Read-Only)
struct CampMapPreview: View {
    let layout: CampLayout
    let searchText: String
    @Binding var selectedItem: PlaceableItem?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid background
                CampGridBackground(layout: layout, geometry: geometry)
                
                // Items
                ForEach(layout.items) { item in
                    CampItemPin(
                        item: item,
                        isHighlighted: isHighlighted(item),
                        isSelected: selectedItem?.id == item.id,
                        geometry: geometry,
                        layout: layout
                    )
                    .onTapGesture {
                        selectedItem = item
                    }
                }
            }
        }
        .background(Theme.Colors.backgroundDark)
    }
    
    func isHighlighted(_ item: PlaceableItem) -> Bool {
        guard !searchText.isEmpty else { return false }
        return item.name.localizedCaseInsensitiveContains(searchText) ||
               item.type.rawValue.localizedCaseInsensitiveContains(searchText) ||
               (item.assignedName?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
}

// MARK: - Camp Grid Background
struct CampGridBackground: View {
    let layout: CampLayout
    let geometry: GeometryProxy
    
    var body: some View {
        Canvas { context, size in
            // Draw grid lines
            let gridSpacing: CGFloat = 20 // 10 feet per grid line
            let scaleX = size.width / CGFloat(layout.grid.widthFeet)
            let scaleY = size.height / CGFloat(layout.grid.depthFeet)
            let scale = min(scaleX, scaleY)
            
            // Vertical lines
            var x: CGFloat = 0
            while x <= layout.grid.widthFeet {
                let path = Path { p in
                    p.move(to: CGPoint(x: x * scale, y: 0))
                    p.addLine(to: CGPoint(x: x * scale, y: layout.grid.depthFeet * scale))
                }
                context.stroke(path, with: .color(Theme.Colors.robotCream.opacity(0.1)), lineWidth: 1)
                x += 10
            }
            
            // Horizontal lines
            var y: CGFloat = 0
            while y <= layout.grid.depthFeet {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y * scale))
                    p.addLine(to: CGPoint(x: layout.grid.widthFeet * scale, y: y * scale))
                }
                context.stroke(path, with: .color(Theme.Colors.robotCream.opacity(0.1)), lineWidth: 1)
                y += 10
            }
        }
    }
}

// MARK: - Camp Item Pin
struct CampItemPin: View {
    let item: PlaceableItem
    let isHighlighted: Bool
    let isSelected: Bool
    let geometry: GeometryProxy
    let layout: CampLayout
    
    var position: CGPoint {
        let scaleX = geometry.size.width / CGFloat(layout.grid.widthFeet)
        let scaleY = geometry.size.height / CGFloat(layout.grid.depthFeet)
        let scale = min(scaleX, scaleY)
        
        return CGPoint(
            x: (item.xPosition + item.widthFeet / 2) * scale,
            y: (item.yPosition + item.depthFeet / 2) * scale
        )
    }
    
    var body: some View {
        ZStack {
            // Item shape
            RoundedRectangle(cornerRadius: 4)
                .fill(item.swiftUIColor.opacity(isHighlighted ? 1.0 : 0.6))
                .frame(width: itemWidth, height: itemHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Theme.Colors.sunsetOrange : Color.clear, lineWidth: 2)
                )
            
            // Label
            Text(item.name.prefix(3).uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white)
        }
        .position(position)
        .shadow(color: isHighlighted ? item.swiftUIColor : .clear, radius: 4)
    }
    
    var itemWidth: CGFloat {
        let scaleX = geometry.size.width / CGFloat(layout.grid.widthFeet)
        return max(20, item.widthFeet * scaleX)
    }
    
    var itemHeight: CGFloat {
        let scaleY = geometry.size.height / CGFloat(layout.grid.depthFeet)
        return max(20, item.depthFeet * scaleY)
    }
}

// MARK: - Search Results List
struct SearchResultsList: View {
    let items: [PlaceableItem]
    @Binding var selectedItem: PlaceableItem?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(items) { item in
                    Button(action: { selectedItem = item }) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: item.type.icon)
                                .foregroundColor(item.swiftUIColor)
                            Text(item.name)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(selectedItem?.id == item.id ? Theme.Colors.sunsetOrange.opacity(0.2) : Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.full)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Selected Item Card
struct SelectedItemCard: View {
    let item: PlaceableItem
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.swiftUIColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.type.icon)
                        .font(.title3)
                        .foregroundColor(item.swiftUIColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text(item.type.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            // Details
            HStack(spacing: Theme.Spacing.lg) {
                DetailPill(icon: "ruler", value: "\(Int(item.widthFeet))×\(Int(item.depthFeet))'")
                
                if let assignee = item.assignedName {
                    DetailPill(icon: "person.fill", value: assignee)
                }
            }
            
            // Navigate button (if has location)
            Button(action: {
                // TODO: Navigate to item location
            }) {
                HStack {
                    Image(systemName: "location.fill")
                    Text("Navigate Here")
                }
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.backgroundDark)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.Colors.turquoise)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
}

struct DetailPill: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(value)
                .font(Theme.Typography.caption)
        }
        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.full)
    }
}

// MARK: - No Camp Layout View
struct NoCampLayoutView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Camp Layout")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Camp admins haven't created a layout yet")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    CampBrowserView()
        .environmentObject(CampLayoutManager())
        .environmentObject(ShiftManager())
}
