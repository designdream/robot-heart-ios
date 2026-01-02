import SwiftUI
import MapKit

// MARK: - Place Search Map View
/// Shows a highlighted destination on a dimmed map with route/directions
struct PlaceSearchMapView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var campLayoutManager: CampLayoutManager
    @Environment(\.dismiss) var dismiss
    
    let destinationName: String
    let destinationItem: PlaceableItem?
    let destinationCoordinate: CLLocationCoordinate2D?
    
    // BRC center and grid constants
    private let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
    private let playaBikeSpeed: Double = 2.2 // meters per second (~5 mph)
    
    @State private var zoomLevel: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    // Calculate distance and time
    var distanceInfo: (distance: Double, time: String)? {
        guard let userLocation = locationManager.location,
              let destCoord = destinationCoordinate else { return nil }
        
        let userCL = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let destCL = CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude)
        let distanceMeters = userCL.distance(from: destCL)
        
        // Calculate bike time
        let timeSeconds = distanceMeters / playaBikeSpeed
        let timeMinutes = Int(timeSeconds / 60)
        
        let timeString: String
        if timeMinutes < 1 {
            timeString = "< 1 min"
        } else if timeMinutes < 60 {
            timeString = "\(timeMinutes) min"
        } else {
            let hours = timeMinutes / 60
            let mins = timeMinutes % 60
            timeString = "\(hours)h \(mins)m"
        }
        
        return (distanceMeters, timeString)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Destination info header
                    destinationHeader
                    
                    // Map with highlighted destination
                    highlightedMapView
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyBy) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    zoomLevel = min(3.0, max(0.5, zoomLevel * value))
                                }
                        )
                    
                    // Distance and directions info
                    directionsFooter
                }
            }
            .navigationTitle("Navigate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
    }
    
    // MARK: - Destination Header
    private var destinationHeader: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Destination icon
            Image(systemName: destinationItem?.type.icon ?? "mappin.circle.fill")
                .font(.title2)
                .foregroundColor(Theme.Colors.goldenYellow)
                .frame(width: 44, height: 44)
                .background(Theme.Colors.goldenYellow.opacity(0.2))
                .cornerRadius(Theme.CornerRadius.sm)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(destinationName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                if let item = destinationItem {
                    Text(item.type.rawValue)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Highlight indicator
            VStack(spacing: 2) {
                Circle()
                    .fill(Theme.Colors.goldenYellow)
                    .frame(width: 12, height: 12)
                Text("Highlighted")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.goldenYellow)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
    }
    
    // MARK: - Highlighted Map View
    private var highlightedMapView: some View {
        GeometryReader { geometry in
            let baseSize = min(geometry.size.width, geometry.size.height) - 20
            let canvasSize = baseSize * zoomLevel * magnifyBy
            
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack {
                    // Dimmed background grid
                    DimmedBRCGrid(canvasSize: canvasSize)
                    
                    // Highlighted destination
                    if let item = destinationItem {
                        HighlightedDestinationMarker(
                            item: item,
                            canvasSize: canvasSize
                        )
                    }
                    
                    // User location marker
                    if locationManager.location != nil {
                        UserLocationMarker(canvasSize: canvasSize)
                    }
                    
                    // Route line (if we have both locations)
                    if let item = destinationItem, locationManager.location != nil {
                        RouteLine(
                            destinationItem: item,
                            canvasSize: canvasSize
                        )
                    }
                }
                .frame(width: canvasSize + 40, height: canvasSize + 40)
            }
        }
        .background(Theme.Colors.backgroundDark)
    }
    
    // MARK: - Directions Footer
    private var directionsFooter: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let info = distanceInfo {
                HStack(spacing: Theme.Spacing.xl) {
                    // Distance
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.turquoise)
                        Text(formatDistance(info.distance))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("Distance")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Divider()
                        .frame(height: 50)
                        .background(Theme.Colors.robotCream.opacity(0.2))
                    
                    // Time by bike
                    VStack(spacing: 4) {
                        Image(systemName: "bicycle")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.goldenYellow)
                        Text(info.time)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("By Bike")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Divider()
                        .frame(height: 50)
                        .background(Theme.Colors.robotCream.opacity(0.2))
                    
                    // Walking time (roughly 3x bike time)
                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.title3)
                            .foregroundColor(Theme.Colors.sunsetOrange)
                        Text(walkingTime(from: info.distance))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("Walking")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                .padding()
            } else {
                // No location available
                HStack {
                    Image(systemName: "location.slash")
                        .foregroundColor(Theme.Colors.warning)
                    Text("Enable location to see distance")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                .padding()
            }
            
            // BRC Address (if available)
            if let item = destinationItem {
                Text("📍 \(item.name) - Camp Layout")
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.goldenYellow)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .background(Theme.Colors.backgroundMedium)
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        } else {
            return String(format: "%.1fkm", meters / 1000)
        }
    }
    
    private func walkingTime(from meters: Double) -> String {
        let walkingSpeed = 1.2 // m/s (~2.7 mph)
        let timeSeconds = meters / walkingSpeed
        let timeMinutes = Int(timeSeconds / 60)
        
        if timeMinutes < 1 {
            return "< 1 min"
        } else if timeMinutes < 60 {
            return "\(timeMinutes) min"
        } else {
            let hours = timeMinutes / 60
            let mins = timeMinutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

// MARK: - Dimmed BRC Grid
struct DimmedBRCGrid: View {
    let canvasSize: CGFloat
    
    var body: some View {
        ZStack {
            // Very dark playa background
            Circle()
                .fill(Theme.Colors.playaDust.opacity(0.1))
                .frame(width: canvasSize, height: canvasSize)
            
            // Dimmed radial streets (clock positions)
            ForEach(0..<12) { hour in
                let angle = Double(hour) * 30 - 90
                Rectangle()
                    .fill(Theme.Colors.robotCream.opacity(0.1))
                    .frame(width: 1, height: canvasSize / 2)
                    .offset(y: -canvasSize / 4)
                    .rotationEffect(.degrees(angle))
            }
            
            // Dimmed ring streets (A-L)
            ForEach(0..<12) { ring in
                let radius = canvasSize * 0.15 + CGFloat(ring) * (canvasSize * 0.035)
                Circle()
                    .stroke(Theme.Colors.robotCream.opacity(0.1), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
            }
            
            // The Man (center) - slightly visible
            Circle()
                .fill(Theme.Colors.sunsetOrange.opacity(0.3))
                .frame(width: 12, height: 12)
            
            // Street labels (dimmed)
            ForEach([2, 4, 6, 8, 10], id: \.self) { hour in
                let angle = Double(hour) * 30 - 90
                let labelRadius = canvasSize * 0.48
                let x = labelRadius * Foundation.cos(angle * .pi / 180)
                let y = labelRadius * Foundation.sin(angle * .pi / 180)
                
                Text("\(hour):00")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.2))
                    .position(x: canvasSize / 2 + x + 20, y: canvasSize / 2 + y + 20)
            }
        }
    }
}

// MARK: - Highlighted Destination Marker
struct HighlightedDestinationMarker: View {
    let item: PlaceableItem
    let canvasSize: CGFloat
    @State private var isPulsing = false
    
    var body: some View {
        let position = calculatePosition()
        
        ZStack {
            // Pulsing highlight ring
            Circle()
                .stroke(Theme.Colors.goldenYellow, lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 0.8)
                .animation(
                    Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            // Solid highlight circle
            Circle()
                .fill(Theme.Colors.goldenYellow.opacity(0.3))
                .frame(width: 50, height: 50)
            
            // Destination icon
            VStack(spacing: 2) {
                Image(systemName: item.type.icon)
                    .font(.title2)
                    .foregroundColor(Theme.Colors.goldenYellow)
                
                Text(item.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.goldenYellow)
                    .lineLimit(1)
            }
        }
        .position(x: position.x + 20, y: position.y + 20)
        .onAppear { isPulsing = true }
    }
    
    private func calculatePosition() -> CGPoint {
        // Convert item position to canvas coordinates
        let x = canvasSize * CGFloat(item.xPosition) / 400.0
        let y = canvasSize * CGFloat(item.yPosition) / 400.0
        return CGPoint(x: x, y: y)
    }
}

// MARK: - User Location Marker
struct UserLocationMarker: View {
    let canvasSize: CGFloat
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulse effect
            Circle()
                .fill(Theme.Colors.turquoise.opacity(0.3))
                .frame(width: 30, height: 30)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .opacity(isPulsing ? 0 : 1)
                .animation(
                    Animation.easeOut(duration: 1.0).repeatForever(autoreverses: false),
                    value: isPulsing
                )
            
            // User dot
            Circle()
                .fill(Theme.Colors.turquoise)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            Text("You")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.Colors.turquoise)
                .offset(y: 16)
        }
        .position(x: canvasSize / 2 + 20, y: canvasSize / 2 + 20) // Center for now
        .onAppear { isPulsing = true }
    }
}

// MARK: - Route Line
struct RouteLine: View {
    let destinationItem: PlaceableItem
    let canvasSize: CGFloat
    
    var body: some View {
        let destPosition = calculateDestPosition()
        let userPosition = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        
        Path { path in
            path.move(to: CGPoint(x: userPosition.x + 20, y: userPosition.y + 20))
            path.addLine(to: CGPoint(x: destPosition.x + 20, y: destPosition.y + 20))
        }
        .stroke(
            Theme.Colors.goldenYellow,
            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10, 5])
        )
    }
    
    private func calculateDestPosition() -> CGPoint {
        let x = canvasSize * CGFloat(destinationItem.xPosition) / 400.0
        let y = canvasSize * CGFloat(destinationItem.yPosition) / 400.0
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Preview
#Preview {
    PlaceSearchMapView(
        destinationName: "Kitchen Tent",
        destinationItem: nil,
        destinationCoordinate: nil
    )
    .environmentObject(LocationManager())
    .environmentObject(CampLayoutManager())
}
