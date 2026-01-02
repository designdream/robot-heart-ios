import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var emergencyManager: EmergencyManager
    @State private var showingShareSheet = false
    @State private var selectedMapType = 0  // 0 = BRC Grid, 1 = Satellite
    @State private var zoomLevel: CGFloat = 1.0
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    // BRC center coordinates (The Man)
    private let brcCenter = CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065)
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.7864, longitude: -119.2065),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    
    var membersWithLocation: [CampMember] {
        meshtasticManager.campMembers.filter { $0.location != nil }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Map type selector
                    Picker("Map Type", selection: $selectedMapType) {
                        Text("BRC Grid").tag(0)
                        Text("Satellite").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, Theme.Spacing.sm)
                    
                    // Map content
                    if selectedMapType == 0 {
                        BRCGridMapView(
                            membersWithLocation: membersWithLocation,
                            zoomLevel: zoomLevel * magnifyBy
                        )
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyBy) { value, state, _ in
                                    state = value
                                }
                                .onEnded { value in
                                    zoomLevel = min(3.0, max(0.5, zoomLevel * value))
                                }
                        )
                    } else {
                        Map(coordinateRegion: $region, annotationItems: membersWithLocation) { member in
                            MapAnnotation(coordinate: member.location!.coordinate) {
                                MemberMapMarker(member: member)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .cornerRadius(Theme.CornerRadius.md)
                        .padding()
                    }
                    
                    // Location sharing controls
                    locationControlsView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Playa Map")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedMapType == 0 {
                        Button(action: { zoomLevel = 1.0 }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                    }
                }
            }
        }
    }
    
    private var locationControlsView: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Sharing status
            if locationManager.isSharing {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(Theme.Colors.connected)
                    Text("Sharing location every \(Int(locationManager.shareInterval / 60)) minutes")
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                .padding()
                .background(Theme.Colors.backgroundMedium)
                .cornerRadius(Theme.CornerRadius.md)
            }
            
            // Action buttons
            HStack(spacing: Theme.Spacing.md) {
                // Share location once
                ActionButton(
                    title: "Share Now",
                    icon: "location.fill",
                    color: Theme.Colors.turquoise,
                    action: {
                        locationManager.shareCurrentLocation()
                    }
                )
                
                // Toggle auto-sharing
                ActionButton(
                    title: locationManager.isSharing ? "Stop Sharing" : "Auto Share",
                    icon: locationManager.isSharing ? "pause.fill" : "play.fill",
                    color: locationManager.isSharing ? Theme.Colors.disconnected : Theme.Colors.connected,
                    action: {
                        if locationManager.isSharing {
                            locationManager.stopSharing()
                        } else {
                            locationManager.startSharing()
                        }
                    }
                )
            }
            
            // SOS Button
            SOSButtonView()
        }
        .padding()
        .background(Theme.Colors.backgroundDark)
    }
}

// MARK: - Member Map Marker
struct MemberMapMarker: View {
    let member: CampMember
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            // Pulse effect for online members
            if member.isOnline {
                Circle()
                    .fill(Theme.Colors.sunsetOrange.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                    .animation(Theme.Animations.pulse, value: isPulsing)
            }
            
            // Marker
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(statusColor(for: member.status))
                        .frame(width: 30, height: 30)
                    
                    Text(member.name.prefix(1))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // Shift indicator
                if member.currentShift?.isActive == true {
                    Image(systemName: member.role.icon)
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Theme.Colors.turquoise)
                        .clipShape(Circle())
                        .offset(y: -5)
                }
            }
        }
        .onAppear {
            if member.isOnline {
                isPulsing = true
            }
        }
    }
    
    private func statusColor(for status: CampMember.ConnectionStatus) -> Color {
        switch status {
        case .connected: return Theme.Colors.connected
        case .recent: return Theme.Colors.warning
        case .offline: return Theme.Colors.disconnected
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Theme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .cornerRadius(Theme.CornerRadius.md)
        }
    }
}

// MARK: - BRC Grid Map View
struct BRCGridMapView: View {
    let membersWithLocation: [CampMember]
    let zoomLevel: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let baseSize = min(geometry.size.width, geometry.size.height) - 40
            let canvasSize = baseSize * zoomLevel
            
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                BRCGridCanvas(canvasSize: canvasSize)
                    .frame(width: canvasSize + 40, height: canvasSize + 40)
            }
        }
        .background(Theme.Colors.backgroundDark)
    }
}

// MARK: - BRC Grid Canvas (separated for compiler)
struct BRCGridCanvas: View {
    let canvasSize: CGFloat
    
    var body: some View {
        ZStack {
            // Playa background
            Circle()
                .fill(Theme.Colors.playaDust.opacity(0.3))
                .frame(width: canvasSize * 1.2, height: canvasSize * 1.2)
            
            // Concentric street arcs
            BRCConcentricStreets(canvasSize: canvasSize)
            
            // Radial streets
            BRCRadialStreets(canvasSize: canvasSize)
            
            // Landmarks
            BRCLandmarks(canvasSize: canvasSize)
        }
        .frame(width: canvasSize, height: canvasSize)
        .padding(20)
    }
}

// MARK: - Concentric Streets
struct BRCConcentricStreets: View {
    let canvasSize: CGFloat
    let streets = ["Esplanade", "Atwood", "Bradbury", "Cherryh", "Dick", "Ellison", "Farmer", "Gibson", "Herbert", "Ishiguro", "Jemisin", "Kilgore"]
    
    var body: some View {
        ForEach(0..<streets.count, id: \.self) { index in
            let radius = CGFloat(index + 1) * (canvasSize / 14)
            let isEsplanade = index == 0
            
            // Arc
            Path { path in
                path.addArc(
                    center: CGPoint(x: canvasSize / 2, y: canvasSize / 2),
                    radius: radius,
                    startAngle: .degrees(-120),
                    endAngle: .degrees(120),
                    clockwise: false
                )
            }
            .stroke(
                isEsplanade ? Theme.Colors.sunsetOrange.opacity(0.8) : Theme.Colors.robotCream.opacity(0.3),
                lineWidth: isEsplanade ? 2 : 1
            )
        }
    }
}

// MARK: - Radial Streets
struct BRCRadialStreets: View {
    let canvasSize: CGFloat
    let times = ["2:00", "3:00", "4:00", "4:30", "5:00", "6:00", "7:00", "7:30", "8:00", "9:00", "10:00"]
    
    var body: some View {
        ForEach(times, id: \.self) { time in
            let angle = clockToAngle(time)
            let innerRadius = canvasSize / 14
            let outerRadius = canvasSize / 2
            let isSixOClock = time == "6:00"
            
            // Line
            Path { path in
                path.move(to: CGPoint(
                    x: canvasSize / 2 + innerRadius * cos(angle),
                    y: canvasSize / 2 + innerRadius * sin(angle)
                ))
                path.addLine(to: CGPoint(
                    x: canvasSize / 2 + outerRadius * cos(angle),
                    y: canvasSize / 2 + outerRadius * sin(angle)
                ))
            }
            .stroke(
                isSixOClock ? Theme.Colors.sunsetOrange.opacity(0.6) : Theme.Colors.robotCream.opacity(0.2),
                lineWidth: isSixOClock ? 2 : 1
            )
            
            // Label
            Text(time)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                .position(
                    x: canvasSize / 2 + (outerRadius + 15) * cos(angle),
                    y: canvasSize / 2 + (outerRadius + 15) * sin(angle)
                )
        }
    }
    
    private func clockToAngle(_ time: String) -> CGFloat {
        let parts = time.split(separator: ":")
        let hours = Double(parts[0]) ?? 0
        let mins = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
        let total = hours + mins / 60
        return (total - 3) * 30 * .pi / 180
    }
}

// MARK: - BRC Landmarks
struct BRCLandmarks: View {
    let canvasSize: CGFloat
    
    var body: some View {
        // The Man
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.sunsetOrange)
            Text("THE MAN")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.Colors.sunsetOrange)
        }
        .position(x: canvasSize / 2, y: canvasSize / 2 - canvasSize / 8)
        
        // Center Camp
        VStack(spacing: 2) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.turquoise)
            Text("Center Camp")
                .font(.system(size: 8))
                .foregroundColor(Theme.Colors.turquoise)
        }
        .position(x: canvasSize / 2, y: canvasSize / 2 + canvasSize / 10)
        
        // Robot Heart (7:30 & G)
        VStack(spacing: 2) {
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundColor(Theme.Colors.sunsetOrange)
            Text("Robot Heart")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Theme.Colors.sunsetOrange)
        }
        .position(brcPosition(time: "7:30", streetIndex: 6))
        
        // Plazas (yellow dots)
        ForEach(["3:00", "4:30", "6:00", "7:30", "9:00"], id: \.self) { time in
            Circle()
                .fill(Theme.Colors.goldenYellow.opacity(0.4))
                .frame(width: 10, height: 10)
                .position(brcPosition(time: time, streetIndex: 1))
            
            Circle()
                .fill(Theme.Colors.goldenYellow.opacity(0.4))
                .frame(width: 10, height: 10)
                .position(brcPosition(time: time, streetIndex: 6))
        }
    }
    
    private func brcPosition(time: String, streetIndex: Int) -> CGPoint {
        let parts = time.split(separator: ":")
        let hours = Double(parts[0]) ?? 0
        let mins = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
        let total = hours + mins / 60
        let angle = CGFloat((total - 3) * 30 * .pi / 180)
        let radius = CGFloat(streetIndex + 1) * (canvasSize / 14)
        
        return CGPoint(
            x: canvasSize / 2 + radius * CoreGraphics.cos(angle),
            y: canvasSize / 2 + radius * CoreGraphics.sin(angle)
        )
    }
}

#Preview {
    MapView()
        .environmentObject(MeshtasticManager())
        .environmentObject(LocationManager())
        .environmentObject(EmergencyManager())
}
