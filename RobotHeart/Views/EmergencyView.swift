import SwiftUI

// MARK: - Emergency Alert Overlay
struct EmergencyAlertOverlay: View {
    @EnvironmentObject var emergencyManager: EmergencyManager
    let emergency: EmergencyManager.Emergency
    
    @State private var isPulsing = false
    @State private var showDetails = false
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    showDetails.toggle()
                }
            
            VStack(spacing: Theme.Spacing.lg) {
                // Pulsing alert icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.emergency.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .scaleEffect(isPulsing ? 1.3 : 1.0)
                        .opacity(isPulsing ? 0 : 1)
                    
                    Circle()
                        .fill(Theme.Colors.emergency)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
                
                // Alert header
                Text("EMERGENCY ALERT")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                
                // Who sent it
                Text(emergency.isFromMe ? "Your SOS is active" : "From: \(emergency.fromName)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                // Message
                Text(emergency.message)
                    .font(Theme.Typography.title2)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Time
                Text(emergency.timeAgoText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                
                // Location info
                if let location = emergency.location {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Location shared")
                    }
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.turquoise)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                }
                
                Spacer()
                
                // Action buttons
                if emergency.isFromMe {
                    // Cancel SOS button
                    Button(action: {
                        emergencyManager.cancelSOS()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("CANCEL SOS")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                } else {
                    // Acknowledge button
                    Button(action: {
                        emergencyManager.acknowledgeEmergency(emergency)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("ACKNOWLEDGE")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.connected)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    
                    // Respond button
                    Button(action: {
                        // TODO: Open messages with pre-filled response
                        emergencyManager.dismissEmergency()
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("RESPOND")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                }
            }
            .padding(Theme.Spacing.xl)
        }
    }
}

// MARK: - SOS Button View
struct SOSButtonView: View {
    @EnvironmentObject var emergencyManager: EmergencyManager
    @EnvironmentObject var locationManager: LocationManager
    
    @State private var isPressed = false
    @State private var holdProgress: CGFloat = 0
    @State private var showingConfirmation = false
    @State private var holdTimer: Timer?
    
    private let holdDuration: TimeInterval = 2.0
    
    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            // SOS Button
            ZStack {
                // Progress ring
                Circle()
                    .stroke(Theme.Colors.emergency.opacity(0.3), lineWidth: 8)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(Theme.Colors.emergency, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                
                // Button
                Circle()
                    .fill(isPressed ? Theme.Colors.emergency : Theme.Colors.emergency.opacity(0.8))
                    .frame(width: 80, height: 80)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                    .shadow(color: Theme.Colors.emergency.opacity(0.5), radius: isPressed ? 5 : 10)
                
                Text("SOS")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            startHold()
                        }
                    }
                    .onEnded { _ in
                        cancelHold()
                    }
            )
            
            Text("Hold for 2 seconds")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .alert("Send Emergency Alert?", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Send SOS", role: .destructive) {
                sendSOS()
            }
        } message: {
            Text("This will alert all camp members with your location.")
        }
    }
    
    private func startHold() {
        isPressed = true
        holdProgress = 0
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        
        // Start progress animation
        withAnimation(.linear(duration: holdDuration)) {
            holdProgress = 1.0
        }
        
        // Timer to trigger SOS
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdDuration, repeats: false) { _ in
            showingConfirmation = true
            cancelHold()
        }
    }
    
    private func cancelHold() {
        isPressed = false
        holdTimer?.invalidate()
        holdTimer = nil
        
        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0
        }
    }
    
    private func sendSOS() {
        let location: (Double, Double)?
        if let loc = locationManager.location {
            location = (loc.coordinate.latitude, loc.coordinate.longitude)
        } else {
            location = nil
        }
        
        emergencyManager.sendSOS(location: location)
    }
}

// MARK: - Emergency History View
struct EmergencyHistoryView: View {
    @EnvironmentObject var emergencyManager: EmergencyManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if emergencyManager.emergencyHistory.isEmpty {
                Text("No emergency history")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            } else {
                ForEach(emergencyManager.emergencyHistory.prefix(10)) { emergency in
                    EmergencyHistoryRow(emergency: emergency)
                }
            }
        }
    }
}

struct EmergencyHistoryRow: View {
    let emergency: EmergencyManager.Emergency
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(emergency.acknowledged ? Theme.Colors.robotCream.opacity(0.5) : Theme.Colors.emergency)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(emergency.fromName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text(emergency.message)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(emergency.timeAgoText)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                if emergency.acknowledged {
                    Text("Resolved")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.connected)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

#Preview {
    ZStack {
        Theme.Colors.backgroundDark.ignoresSafeArea()
        SOSButtonView()
    }
    .environmentObject(EmergencyManager())
    .environmentObject(LocationManager())
}
