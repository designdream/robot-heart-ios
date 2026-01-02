import SwiftUI

// MARK: - Camp Layout Planner View
struct CampLayoutPlannerView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingCreateLayout = false
    @State private var showingAddItem = false
    @State private var showingAddLane = false
    @State private var showingItemLibrary = false
    @State private var showingValidation = false
    @State private var showingExport = false
    @State private var showingSearch = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                if let layout = layoutManager.currentLayout {
                    VStack(spacing: 0) {
                        // Search bar (when active)
                        if showingSearch {
                            LayoutSearchBar(
                                searchText: $searchText,
                                showingSearch: $showingSearch,
                                layout: layout
                            )
                        }
                        
                        // Stats bar
                        LayoutStatsBar(layout: layout)
                        
                        // Grid canvas with search highlighting
                        LayoutCanvasView(searchText: searchText)
                        
                        // Toolbar
                        LayoutToolbar(
                            showingAddItem: $showingAddItem,
                            showingAddLane: $showingAddLane,
                            showingItemLibrary: $showingItemLibrary
                        )
                    }
                } else {
                    NoLayoutView(showingCreate: $showingCreateLayout)
                }
            }
            .navigationTitle(layoutManager.currentLayout?.grid.name ?? "Camp Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Menu {
                            Button(action: { showingCreateLayout = true }) {
                                Label("New Layout", systemImage: "plus.rectangle")
                            }
                            
                            if !layoutManager.savedLayouts.isEmpty {
                                Menu("Load Layout") {
                                    ForEach(layoutManager.savedLayouts) { layout in
                                        Button(layout.grid.name) {
                                            layoutManager.loadLayout(layout)
                                        }
                                    }
                                }
                            }
                            
                            if layoutManager.hasLayout {
                                Divider()
                                
                                Button(action: { layoutManager.saveLayout() }) {
                                    Label("Save", systemImage: "square.and.arrow.down")
                                }
                                
                                Button(action: { showingExport = true }) {
                                    Label("Export Summary", systemImage: "doc.text")
                                }
                            }
                        } label: {
                            Image(systemName: "folder")
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                        
                        // Search button
                        if layoutManager.hasLayout {
                            Button(action: { 
                                withAnimation { showingSearch.toggle() }
                                if !showingSearch { searchText = "" }
                            }) {
                                Image(systemName: showingSearch ? "xmark.circle.fill" : "magnifyingglass")
                                    .foregroundColor(showingSearch ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if layoutManager.hasLayout {
                        HStack(spacing: Theme.Spacing.sm) {
                            // Validation indicator
                            Button(action: { showingValidation = true }) {
                                Image(systemName: layoutManager.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(layoutManager.isValid ? Theme.Colors.connected : Theme.Colors.warning)
                            }
                            
                            // Grid toggle
                            Button(action: { layoutManager.showGrid.toggle() }) {
                                Image(systemName: layoutManager.showGrid ? "grid" : "grid.circle")
                                    .foregroundColor(Theme.Colors.robotCream)
                            }
                            
                            // Snap toggle
                            Button(action: { layoutManager.snapToGrid.toggle() }) {
                                Image(systemName: layoutManager.snapToGrid ? "square.grid.3x3.fill" : "square.grid.3x3")
                                    .foregroundColor(layoutManager.snapToGrid ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingCreateLayout) {
                CreateLayoutView()
            }
            .sheet(isPresented: $showingAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showingAddLane) {
                AddLaneView()
            }
            .sheet(isPresented: $showingItemLibrary) {
                ItemLibraryView()
            }
            .sheet(isPresented: $showingValidation) {
                ValidationView()
            }
            .sheet(isPresented: $showingExport) {
                ExportView()
            }
        }
    }
}

// MARK: - No Layout View
struct NoLayoutView: View {
    @Binding var showingCreate: Bool
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "map")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
            
            Text("No Camp Layout")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Create a layout to start planning your camp placement")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button(action: { showingCreate = true }) {
                HStack {
                    Image(systemName: "plus.rectangle")
                    Text("Create Layout")
                }
                .font(Theme.Typography.callout)
                .foregroundColor(Theme.Colors.backgroundDark)
                .padding()
                .background(Theme.Colors.sunsetOrange)
                .cornerRadius(Theme.CornerRadius.md)
            }
        }
        .padding()
    }
}

// MARK: - Layout Stats Bar
struct LayoutStatsBar: View {
    let layout: CampLayout
    @EnvironmentObject var layoutManager: CampLayoutManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                LayoutStatChip(
                    label: "Size",
                    value: "\(Int(layout.grid.widthFeet))' × \(Int(layout.grid.depthFeet))'"
                )
                
                LayoutStatChip(
                    label: "Used",
                    value: String(format: "%.0f%%", layout.usedPercentage),
                    color: layout.usedPercentage > 80 ? Theme.Colors.warning : Theme.Colors.connected
                )
                
                LayoutStatChip(
                    label: "RVs",
                    value: "\(layout.rvCount)"
                )
                
                LayoutStatChip(
                    label: "Items",
                    value: "\(layout.items.count)"
                )
                
                LayoutStatChip(
                    label: "Lanes",
                    value: "\(layout.lanes.count)"
                )
            }
            .padding(.horizontal)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(Theme.Colors.backgroundMedium)
    }
}

// MARK: - Layout Stat Chip
struct LayoutStatChip: View {
    let label: String
    let value: String
    var color: Color = Theme.Colors.turquoise
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(Theme.Typography.footnote)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Layout Search Bar
struct LayoutSearchBar: View {
    @Binding var searchText: String
    @Binding var showingSearch: Bool
    let layout: CampLayout
    
    var matchingItems: [PlaceableItem] {
        guard !searchText.isEmpty else { return [] }
        return layout.items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText) ||
            (item.assignedName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                TextField("Search for RV, tent, or person...", text: $searchText)
                    .foregroundColor(Theme.Colors.robotCream)
                    .autocapitalization(.none)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
            
            // Search results hint
            if !searchText.isEmpty {
                HStack {
                    if matchingItems.isEmpty {
                        Text("No matches found")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.warning)
                    } else {
                        Text("\(matchingItems.count) match\(matchingItems.count == 1 ? "" : "es") - highlighted on map")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.connected)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.backgroundLight)
            }
        }
    }
}

// MARK: - Layout Canvas View
struct LayoutCanvasView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    var searchText: String = ""
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    // Check if item matches search
    func itemMatchesSearch(_ item: PlaceableItem) -> Bool {
        guard !searchText.isEmpty else { return false }
        return item.name.localizedCaseInsensitiveContains(searchText) ||
               (item.assignedName?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
    
    // Check if any item matches (to know if we should gray out non-matches)
    var hasSearchResults: Bool {
        guard !searchText.isEmpty else { return false }
        return layoutManager.currentLayout?.items.contains { itemMatchesSearch($0) } ?? false
    }
    
    var body: some View {
        GeometryReader { geometry in
            let canvasSize = calculateCanvasSize(in: geometry.size)
            let zoom = layoutManager.zoomLevel * magnifyBy
            
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    // Background - playa dust color
                    Rectangle()
                        .fill(Theme.Colors.playaDust.opacity(0.3))
                        .frame(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
                    
                    // Grid lines
                    if layoutManager.showGrid, let grid = layoutManager.currentLayout?.grid {
                        GridLinesView(grid: grid, canvasSize: CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom))
                    }
                    
                    // Lanes (gray out if searching)
                    if let lanes = layoutManager.currentLayout?.lanes {
                        ForEach(lanes) { lane in
                            LaneView(lane: lane, canvasSize: CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom))
                                .opacity(hasSearchResults ? 0.2 : 1.0)
                        }
                    }
                    
                    // Items - with search highlighting
                    if let items = layoutManager.currentLayout?.items, let grid = layoutManager.currentLayout?.grid {
                        ForEach(items) { item in
                            let isMatch = itemMatchesSearch(item)
                            let shouldGrayOut = hasSearchResults && !isMatch
                            
                            DraggableItemView(
                                item: item,
                                canvasSize: CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom),
                                gridSize: CGSize(width: grid.widthFeet, height: grid.depthFeet),
                                isHighlighted: isMatch,
                                isGrayedOut: shouldGrayOut
                            )
                        }
                    }
                    
                    // Dimension labels
                    if let grid = layoutManager.currentLayout?.grid {
                        // Width label at top
                        Text("\(Int(grid.widthFeet))'")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.robotCream)
                            .position(x: canvasSize.width * zoom / 2, y: -10)
                        
                        // Depth label on left
                        Text("\(Int(grid.depthFeet))'")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.robotCream)
                            .rotationEffect(.degrees(-90))
                            .position(x: -15, y: canvasSize.height * zoom / 2)
                    }
                }
                .frame(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
                .background(Theme.Colors.backgroundDark)
                .cornerRadius(Theme.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.robotCream.opacity(0.5), lineWidth: 2)
                )
                .padding(20)
            }
            .gesture(
                MagnificationGesture()
                    .updating($magnifyBy) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        layoutManager.zoomLevel = min(3.0, max(0.5, layoutManager.zoomLevel * value))
                    }
            )
        }
    }
    
    private func calculateCanvasSize(in available: CGSize) -> CGSize {
        guard let grid = layoutManager.currentLayout?.grid else {
            return CGSize(width: 300, height: 300)
        }
        
        let aspectRatio = grid.widthFeet / grid.depthFeet
        let padding: CGFloat = 40
        let maxWidth = available.width - padding
        let maxHeight = available.height - padding
        
        var width: CGFloat
        var height: CGFloat
        
        if maxWidth / maxHeight > CGFloat(aspectRatio) {
            height = maxHeight
            width = height * CGFloat(aspectRatio)
        } else {
            width = maxWidth
            height = width / CGFloat(aspectRatio)
        }
        
        return CGSize(width: max(200, width), height: max(200, height))
    }
}

// MARK: - Grid Lines View
struct GridLinesView: View {
    let grid: CampGrid
    let canvasSize: CGSize
    
    var body: some View {
        Canvas { context, size in
            let scaleX = size.width / CGFloat(grid.widthFeet)
            let scaleY = size.height / CGFloat(grid.depthFeet)
            
            // Vertical lines
            for i in 0...grid.gridColumns {
                let x = CGFloat(i) * CGFloat(grid.gridUnitFeet) * scaleX
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Theme.Colors.robotCream.opacity(0.1)), lineWidth: 0.5)
            }
            
            // Horizontal lines
            for i in 0...grid.gridRows {
                let y = CGFloat(i) * CGFloat(grid.gridUnitFeet) * scaleY
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Theme.Colors.robotCream.opacity(0.1)), lineWidth: 0.5)
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
    }
}

// MARK: - Lane View
struct LaneView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    let lane: CampLane
    let canvasSize: CGSize
    
    var body: some View {
        let grid = layoutManager.currentLayout?.grid
        let scaleX = canvasSize.width / CGFloat(grid?.widthFeet ?? 1)
        let scaleY = canvasSize.height / CGFloat(grid?.depthFeet ?? 1)
        
        let startX = CGFloat(lane.startX) * scaleX
        let startY = CGFloat(lane.startY) * scaleY
        let endX = CGFloat(lane.endX) * scaleX
        let endY = CGFloat(lane.endY) * scaleY
        let width = CGFloat(lane.widthFeet) * min(scaleX, scaleY)
        
        Path { path in
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        .stroke(lane.type.color, style: StrokeStyle(lineWidth: width, lineCap: .round))
        .onTapGesture {
            layoutManager.selectedLane = lane
            layoutManager.selectedItem = nil
        }
    }
}

// MARK: - Draggable Item View
struct DraggableItemView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    let item: PlaceableItem
    let canvasSize: CGSize
    let gridSize: CGSize  // In feet
    var isHighlighted: Bool = false
    var isGrayedOut: Bool = false
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var showingAssignment: Bool = false
    
    var isSelected: Bool {
        layoutManager.selectedItem?.id == item.id
    }
    
    var scaleX: CGFloat {
        canvasSize.width / gridSize.width
    }
    
    var scaleY: CGFloat {
        canvasSize.height / gridSize.height
    }
    
    // Calculate current position in feet during drag
    var currentPositionFeet: (x: Double, y: Double) {
        var newX = item.xPosition + Double(dragOffset.width) / Double(scaleX)
        var newY = item.yPosition + Double(dragOffset.height) / Double(scaleY)
        
        // Snap to grid if enabled
        if layoutManager.snapToGrid, let grid = layoutManager.currentLayout?.grid {
            newX = round(newX / grid.gridUnitFeet) * grid.gridUnitFeet
            newY = round(newY / grid.gridUnitFeet) * grid.gridUnitFeet
        }
        
        // Clamp to bounds
        newX = max(0, min(newX, Double(gridSize.width) - item.effectiveWidth))
        newY = max(0, min(newY, Double(gridSize.height) - item.effectiveDepth))
        
        return (newX, newY)
    }
    
    var body: some View {
        let width = CGFloat(item.effectiveWidth) * scaleX
        let height = CGFloat(item.effectiveDepth) * scaleY
        
        // Determine colors based on highlight/gray state
        let fillOpacity: Double = isGrayedOut ? 0.08 : (isDragging ? 0.5 : 0.3)
        let strokeColor: Color = isHighlighted ? Theme.Colors.sunsetOrange : 
                                 (isSelected || isDragging ? Theme.Colors.sunsetOrange : 
                                 (isGrayedOut ? Color.gray.opacity(0.3) : Theme.Colors.robotCream.opacity(0.6)))
        let strokeWidth: CGFloat = isHighlighted ? 3 : (isSelected || isDragging ? 2 : 1)
        
        // Use offset positioning instead of position() for proper ZStack alignment
        ZStack {
            // Main item rectangle - lighter fill so you can see the grid through it
            RoundedRectangle(cornerRadius: 2)
                .fill(isGrayedOut ? Color.gray.opacity(fillOpacity) : item.swiftUIColor.opacity(fillOpacity))
            
            // Clear border outline showing exact dimensions
            RoundedRectangle(cornerRadius: 2)
                .stroke(strokeColor, lineWidth: strokeWidth)
            
            // Dashed inner border for better dimension visibility
            if !isGrayedOut && !isDragging {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.Colors.robotCream.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [4, 2]))
                    .padding(2)
            }
            
            // Highlight glow effect for search matches
            if isHighlighted {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Theme.Colors.sunsetOrange, lineWidth: 2)
                    .blur(radius: 4)
            }
            
            // Content - icon, name, and dimensions
            VStack(spacing: 1) {
                // Icon
                Image(systemName: item.type.icon)
                    .font(.system(size: max(10, min(width, height) * 0.2)))
                    .foregroundColor(isGrayedOut ? .gray : item.swiftUIColor)
                
                // Name (if space allows)
                if width > 40 && height > 35 {
                    Text(item.assignedName ?? item.name)
                        .font(.system(size: max(7, min(9, width * 0.12)), weight: .semibold))
                        .foregroundColor(isGrayedOut ? .gray : Theme.Colors.robotCream)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                
                // Dimensions label (always show if space allows)
                if width > 30 && height > 25 {
                    Text("\(Int(item.effectiveWidth))×\(Int(item.effectiveDepth))")
                        .font(.system(size: max(6, min(8, width * 0.1)), weight: .medium, design: .monospaced))
                        .foregroundColor(isGrayedOut ? .gray.opacity(0.5) : Theme.Colors.robotCream.opacity(0.7))
                }
            }
            .padding(2)
            
            // Assigned person badge
            if item.assignedName != nil && width > 25 {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "person.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.white)
                            .padding(2)
                            .background(isGrayedOut ? Color.gray : Theme.Colors.turquoise)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(1)
            }
            
            // Position label while dragging
            if isDragging {
                VStack {
                    Text("\(Int(currentPositionFeet.x))' × \(Int(currentPositionFeet.y))'")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(4)
                }
            }
            
            // "FOUND" label for highlighted items
            if isHighlighted && !isDragging {
                VStack {
                    Spacer()
                    Text("📍")
                        .font(.system(size: 12))
                        .padding(2)
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(3)
                        .offset(y: 6)
                }
            }
        }
        .frame(width: max(width, 20), height: max(height, 20))
        .offset(
            x: CGFloat(item.xPosition) * scaleX + dragOffset.width,
            y: CGFloat(item.yPosition) * scaleY + dragOffset.height
        )
        .shadow(color: isHighlighted ? Theme.Colors.sunsetOrange.opacity(0.6) : (isDragging ? .black.opacity(0.4) : .clear), radius: isHighlighted ? 15 : 10, x: isHighlighted ? 0 : 4, y: isHighlighted ? 0 : 4)
        .zIndex(isHighlighted ? 100 : (isDragging ? 50 : 0))
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    dragOffset = value.translation
                    isDragging = true
                    layoutManager.isDragging = true
                }
                .onEnded { _ in
                    let pos = currentPositionFeet
                    layoutManager.moveItem(item.id, to: CGPoint(x: pos.x, y: pos.y))
                    dragOffset = .zero
                    isDragging = false
                    layoutManager.isDragging = false
                }
        )
        .onTapGesture {
            layoutManager.selectedItem = item
            layoutManager.selectedLane = nil
        }
        .onLongPressGesture {
            layoutManager.selectedItem = item
            showingAssignment = true
        }
        .sheet(isPresented: $showingAssignment) {
            AssignMemberView(item: item)
        }
    }
}

// MARK: - Layout Toolbar
struct LayoutToolbar: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Binding var showingAddItem: Bool
    @Binding var showingAddLane: Bool
    @Binding var showingItemLibrary: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Selected item controls
            if let item = layoutManager.selectedItem {
                SelectedItemBar(item: item)
            } else if let lane = layoutManager.selectedLane {
                SelectedLaneBar(lane: lane)
            }
            
            // Main toolbar
            HStack(spacing: Theme.Spacing.lg) {
                ToolbarButton(icon: "plus.rectangle.fill", label: "Add Item") {
                    showingAddItem = true
                }
                
                ToolbarButton(icon: "road.lanes", label: "Add Lane") {
                    showingAddLane = true
                }
                
                ToolbarButton(icon: "square.grid.2x2", label: "Library") {
                    showingItemLibrary = true
                }
                
                Spacer()
                
                // Zoom controls
                HStack(spacing: Theme.Spacing.sm) {
                    Button(action: { layoutManager.zoomLevel = max(0.5, layoutManager.zoomLevel - 0.1) }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    
                    Text(String(format: "%.0f%%", layoutManager.zoomLevel * 100))
                        .font(Theme.Typography.caption)
                    
                    Button(action: { layoutManager.zoomLevel = min(2.0, layoutManager.zoomLevel + 0.1) }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                }
                .foregroundColor(Theme.Colors.robotCream)
            }
            .padding()
            .background(Theme.Colors.backgroundMedium)
        }
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(Theme.Typography.footnote)
            }
            .foregroundColor(Theme.Colors.robotCream)
        }
    }
}

// MARK: - Selected Item Bar
struct SelectedItemBar: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    let item: PlaceableItem
    @State private var showingAssignment = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: item.type.icon)
                    .foregroundColor(item.swiftUIColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("\(Int(item.widthFeet))' × \(Int(item.depthFeet))'")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        
                        Text("at \(Int(item.xPosition))' × \(Int(item.yPosition))'")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                }
                
                Spacer()
                
                // Assign button
                Button(action: { showingAssignment = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.plus")
                        if let name = item.assignedName {
                            Text(name)
                                .lineLimit(1)
                        }
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(item.assignedName != nil ? Theme.Colors.turquoise : Theme.Colors.robotCream.opacity(0.6))
                }
                
                Button(action: { layoutManager.rotateItem(item.id) }) {
                    Image(systemName: "rotate.right")
                        .foregroundColor(Theme.Colors.turquoise)
                }
                
                Button(action: { layoutManager.deleteItem(item.id) }) {
                    Image(systemName: "trash")
                        .foregroundColor(Theme.Colors.disconnected)
                }
                
                Button(action: { layoutManager.selectedItem = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            .padding()
        }
        .background(Theme.Colors.backgroundLight)
        .sheet(isPresented: $showingAssignment) {
            AssignMemberView(item: item)
        }
    }
}

// MARK: - Selected Lane Bar
struct SelectedLaneBar: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    let lane: CampLane
    
    var body: some View {
        HStack {
            Image(systemName: lane.type.icon)
                .foregroundColor(lane.type.color)
            
            Text(lane.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("\(Int(lane.widthFeet))' wide")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            
            Spacer()
            
            Button(action: { layoutManager.deleteLane(lane.id) }) {
                Image(systemName: "trash")
                    .foregroundColor(Theme.Colors.disconnected)
            }
            
            Button(action: { layoutManager.selectedLane = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
    }
}

// MARK: - Create Layout View
struct CreateLayoutView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    @State private var name = "Robot Heart Camp"
    @State private var widthFeet = "400"   // Max for established camps per BM
    @State private var depthFeet = "400"   // Max for established camps per BM
    @State private var gridUnit = "50"     // BM requires 50' increments
    @State private var selectedPreset: CampSizePreset = .large
    
    // Camp size presets based on Burning Man placement guidelines
    enum CampSizePreset: String, CaseIterable {
        case newCamp = "New Camp (max 100'×100')"
        case small = "Small (150'×150')"
        case medium = "Medium (200'×200')"
        case large = "Large (300'×300')"
        case maxSize = "Max Size (400'×400')"
        case custom = "Custom"
        
        var dimensions: (width: Int, depth: Int)? {
            switch self {
            case .newCamp: return (100, 100)
            case .small: return (150, 150)
            case .medium: return (200, 200)
            case .large: return (300, 300)
            case .maxSize: return (400, 400)
            case .custom: return nil
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Layout Name", text: $name)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Name")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    // Preset selector
                    Section {
                        Picker("Camp Size", selection: $selectedPreset) {
                            ForEach(CampSizePreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue).tag(preset)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        .onChange(of: selectedPreset) { newValue in
                            if let dims = newValue.dimensions {
                                widthFeet = "\(dims.width)"
                                depthFeet = "\(dims.depth)"
                            }
                        }
                    } header: {
                        Text("Size Preset")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Per Burning Man: New camps max 100'×100', established camps max 400'×400'")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Section {
                        HStack {
                            Text("Width")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            TextField("Width", text: $widthFeet)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.Colors.robotCream)
                                .onChange(of: widthFeet) { _ in selectedPreset = .custom }
                            Text("feet")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                        
                        HStack {
                            Text("Depth")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            TextField("Depth", text: $depthFeet)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.Colors.robotCream)
                                .onChange(of: depthFeet) { _ in selectedPreset = .custom }
                            Text("feet")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                    } header: {
                        Text("Dimensions (from Placement)")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let w = Double(widthFeet), let d = Double(depthFeet) {
                                Text("Total area: \(Int(w * d).formatted()) sq ft")
                                    .foregroundColor(Theme.Colors.turquoise)
                                if w > 100 || d > 100 {
                                    Text("⚠️ Fire lane required (20' min)")
                                        .foregroundColor(Theme.Colors.warning)
                                }
                            }
                            Text("Note: BM requires 50' increments (e.g., 200'×250')")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        }
                    }
                    
                    Section {
                        Picker("Grid Unit", selection: $gridUnit) {
                            Text("50 feet (BM standard)").tag("50")
                            Text("10 feet").tag("10")
                            Text("5 feet").tag("5")
                            Text("1 foot").tag("1")
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Grid Settings")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Items will snap to this grid size")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createLayout()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(name.isEmpty || widthFeet.isEmpty || depthFeet.isEmpty)
                }
            }
        }
    }
    
    private func createLayout() {
        guard let width = Double(widthFeet),
              let depth = Double(depthFeet),
              let unit = Double(gridUnit) else { return }
        
        layoutManager.createLayout(widthFeet: width, depthFeet: depth, name: name, gridUnit: unit)
        dismiss()
    }
}

// MARK: - Add Item View
struct AddItemView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType: PlaceableItem.ItemType = .rv
    @State private var name = ""
    @State private var widthFeet = ""
    @State private var depthFeet = ""
    @State private var selectedPreset: Int?
    @State private var itemsAdded: Int = 0
    @State private var showingAddedFeedback = false
    @State private var lastAddedName = ""
    
    var presets: [(name: String, width: Double, depth: Double)] {
        selectedType.presetSizes
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Feedback banner when item added
                    if showingAddedFeedback {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.Colors.connected)
                            Text("Added \"\(lastAddedName)\" to center of map")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                        }
                        .padding()
                        .background(Theme.Colors.connected.opacity(0.2))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Form {
                        // Items added counter
                        if itemsAdded > 0 {
                            Section {
                                HStack {
                                    Image(systemName: "cube.box.fill")
                                        .foregroundColor(Theme.Colors.turquoise)
                                    Text("\(itemsAdded) item\(itemsAdded == 1 ? "" : "s") added this session")
                                        .foregroundColor(Theme.Colors.turquoise)
                                    Spacer()
                                    Button("Done") {
                                        dismiss()
                                    }
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                                    .fontWeight(.semibold)
                                }
                            }
                        }
                        
                        Section {
                            Picker("Type", selection: $selectedType) {
                                ForEach(PlaceableItem.ItemType.allCases, id: \.self) { type in
                                    Label(type.rawValue, systemImage: type.icon).tag(type)
                                }
                            }
                            .foregroundColor(Theme.Colors.robotCream)
                            .onChange(of: selectedType) { _ in
                                selectedPreset = nil
                                name = ""
                                widthFeet = ""
                                depthFeet = ""
                            }
                            
                            TextField("Name (e.g., Felipe's RV)", text: $name)
                                .foregroundColor(Theme.Colors.robotCream)
                        } header: {
                            Text("Item Type")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        }
                        
                        Section {
                            ForEach(Array(presets.enumerated()), id: \.offset) { index, preset in
                                Button(action: {
                                    selectedPreset = index
                                    if name.isEmpty {
                                        name = preset.name
                                    }
                                    widthFeet = String(format: "%.1f", preset.width)
                                    depthFeet = String(format: "%.1f", preset.depth)
                                }) {
                                    HStack {
                                        Text(preset.name)
                                            .foregroundColor(Theme.Colors.robotCream)
                                        Spacer()
                                        Text("\(Int(preset.width))' × \(Int(preset.depth))'")
                                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                        if selectedPreset == index {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(Theme.Colors.sunsetOrange)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text("Quick Presets (tap to select)")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        }
                        
                        Section {
                            HStack {
                                Text("Width")
                                    .foregroundColor(Theme.Colors.robotCream)
                                Spacer()
                                TextField("Width", text: $widthFeet)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Theme.Colors.robotCream)
                                Text("feet")
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            }
                            
                            HStack {
                                Text("Depth")
                                    .foregroundColor(Theme.Colors.robotCream)
                                Spacer()
                                TextField("Depth", text: $depthFeet)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(Theme.Colors.robotCream)
                                Text("feet")
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            }
                        } header: {
                            Text("Custom Size")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(itemsAdded > 0 ? "Done" : "Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { addItem() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add")
                        }
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(name.isEmpty || widthFeet.isEmpty || depthFeet.isEmpty)
                }
            }
        }
    }
    
    private func addItem() {
        guard let width = Double(widthFeet),
              let depth = Double(depthFeet) else { return }
        
        layoutManager.addItem(type: selectedType, name: name, width: width, depth: depth)
        
        // Show feedback
        lastAddedName = name
        itemsAdded += 1
        withAnimation(.easeInOut(duration: 0.3)) {
            showingAddedFeedback = true
        }
        
        // Hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingAddedFeedback = false
            }
        }
        
        // Clear form for next item (keep type selected)
        name = ""
        selectedPreset = nil
        // Keep width/depth for convenience when adding similar items
    }
}

// MARK: - Add Lane View
struct AddLaneView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType: CampLane.LaneType = .fireLane
    @State private var name = ""
    @State private var orientation: Orientation = .horizontal
    @State private var position = ""
    
    enum Orientation: String, CaseIterable {
        case horizontal = "Horizontal"
        case vertical = "Vertical"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        Picker("Type", selection: $selectedType) {
                            ForEach(CampLane.LaneType.allCases, id: \.self) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        TextField("Name", text: $name)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Lane Type")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Minimum width: \(Int(selectedType.minWidthFeet)) feet")
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                    
                    Section {
                        Picker("Orientation", selection: $orientation) {
                            ForEach(Orientation.allCases, id: \.self) { o in
                                Text(o.rawValue).tag(o)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        HStack {
                            Text(orientation == .horizontal ? "Y Position" : "X Position")
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            TextField("Position", text: $position)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.Colors.robotCream)
                            Text("feet")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                    } header: {
                        Text("Position")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("Lane will span the full width/depth of the camp")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Lane")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addLane()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(name.isEmpty || position.isEmpty)
                }
            }
        }
    }
    
    private func addLane() {
        guard let pos = Double(position) else { return }
        
        if orientation == .horizontal {
            layoutManager.addHorizontalLane(type: selectedType, name: name, yPosition: pos)
        } else {
            layoutManager.addVerticalLane(type: selectedType, name: name, xPosition: pos)
        }
        
        dismiss()
    }
}

// MARK: - Item Library View
struct ItemLibraryView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(PlaceableItem.ItemType.allCases, id: \.self) { type in
                            ItemTypeSection(type: type)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Item Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

// MARK: - Item Type Section
struct ItemTypeSection: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    let type: PlaceableItem.ItemType
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: type.icon)
                        .foregroundColor(Color(hex: type.defaultColor))
                    Text(type.rawValue)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            if isExpanded {
                ForEach(Array(type.presetSizes.enumerated()), id: \.offset) { _, preset in
                    Button(action: {
                        layoutManager.addItem(type: type, name: preset.name, width: preset.width, depth: preset.depth)
                    }) {
                        HStack {
                            Text(preset.name)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            Text("\(Int(preset.width))' × \(Int(preset.depth))'")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                        }
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.sm)
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Validation View
struct ValidationView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                if layoutManager.validationErrors.isEmpty {
                    VStack(spacing: Theme.Spacing.lg) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.connected)
                        
                        Text("Layout Valid")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text("No overlaps or out-of-bounds items")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                } else {
                    List {
                        ForEach(layoutManager.validationErrors, id: \.self) { error in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(Theme.Colors.warning)
                                Text(error)
                                    .foregroundColor(Theme.Colors.robotCream)
                            }
                            .listRowBackground(Theme.Colors.backgroundMedium)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Validation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

// MARK: - Export View
struct ExportView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    Text(layoutManager.exportLayoutSummary())
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(Theme.Colors.robotCream)
                        .padding()
                }
            }
            .navigationTitle("Layout Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ShareLink(item: layoutManager.exportLayoutSummary()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(Theme.Colors.turquoise)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
}

// MARK: - Assign Member View
struct AssignMemberView: View {
    @EnvironmentObject var layoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    let item: PlaceableItem
    @State private var assigneeName = ""
    
    // Get list of names already assigned to other items
    var existingAssignments: [(name: String, itemName: String)] {
        guard let items = layoutManager.currentLayout?.items else { return [] }
        return items.compactMap { item in
            guard let name = item.assignedName else { return nil }
            return (name: name, itemName: item.name)
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.md) {
                    // Item info
                    HStack {
                        Image(systemName: item.type.icon)
                            .font(.title2)
                            .foregroundColor(item.swiftUIColor)
                        
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            Text("\(Int(item.widthFeet))' × \(Int(item.depthFeet))' at position \(Int(item.xPosition))' × \(Int(item.yPosition))'")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                    
                    // Current assignment
                    if let currentName = item.assignedName {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(Theme.Colors.turquoise)
                            Text("Assigned to: \(currentName)")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream)
                            Spacer()
                            Button("Remove") {
                                layoutManager.updateItem(item.id) { item in
                                    item.assignedTo = nil
                                    item.assignedName = nil
                                }
                                dismiss()
                            }
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.disconnected)
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    
                    // Name entry
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Assign to:")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                        
                        HStack {
                            TextField("Enter name (e.g., playa name)", text: $assigneeName)
                                .foregroundColor(Theme.Colors.robotCream)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(Theme.Colors.backgroundLight)
                                .cornerRadius(Theme.CornerRadius.sm)
                            
                            Button(action: assignName) {
                                Text("Assign")
                                    .font(Theme.Typography.callout)
                                    .foregroundColor(Theme.Colors.backgroundDark)
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .background(assigneeName.isEmpty ? Theme.Colors.robotCream.opacity(0.3) : Theme.Colors.sunsetOrange)
                                    .cornerRadius(Theme.CornerRadius.sm)
                            }
                            .disabled(assigneeName.isEmpty)
                        }
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                    
                    // Quick assign from existing names
                    if !existingAssignments.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Or select from existing:")
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                            
                            ScrollView {
                                LazyVStack(spacing: Theme.Spacing.xs) {
                                    ForEach(existingAssignments, id: \.name) { assignment in
                                        Button(action: {
                                            assigneeName = assignment.name
                                            assignName()
                                        }) {
                                            HStack {
                                                Text(assignment.name)
                                                    .font(Theme.Typography.body)
                                                    .foregroundColor(Theme.Colors.robotCream)
                                                Spacer()
                                                Text("(\(assignment.itemName))")
                                                    .font(Theme.Typography.caption)
                                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                            }
                                            .padding()
                                            .background(Theme.Colors.backgroundLight)
                                            .cornerRadius(Theme.CornerRadius.sm)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Assign \(item.type.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
        .onAppear {
            assigneeName = item.assignedName ?? ""
        }
    }
    
    private func assignName() {
        guard !assigneeName.isEmpty else { return }
        layoutManager.updateItem(item.id) { item in
            item.assignedName = assigneeName
        }
        dismiss()
    }
}

#Preview {
    CampLayoutPlannerView()
        .environmentObject(CampLayoutManager())
        .environmentObject(ProfileManager())
}
