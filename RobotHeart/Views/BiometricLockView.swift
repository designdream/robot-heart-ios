import SwiftUI

// MARK: - Biometric Lock View
/// Lock screen that requires biometric authentication to access the app.
/// Shows when app launches or returns from background (if enabled).
struct BiometricLockView: View {
    @Binding var isUnlocked: Bool
    @EnvironmentObject var biometricAuthManager: BiometricAuthManager
    
    @State private var isAuthenticating = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                
                // Logo
                Image("RobotHeartLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .shadow(color: Theme.Colors.sunsetOrange.opacity(0.3), radius: 20)
                
                Text("Robot Heart")
                    .font(Theme.Typography.title1)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("Tap to unlock")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                
                Spacer()
                
                // Unlock button
                Button(action: authenticate) {
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: biometricIcon)
                            .font(.system(size: 48))
                            .foregroundColor(Theme.Colors.turquoise)
                        
                        Text(biometricAuthManager.biometricType.rawValue)
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                    }
                    .frame(width: 120, height: 120)
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.lg)
                }
                .disabled(isAuthenticating)
                .opacity(isAuthenticating ? 0.5 : 1)
                
                if showError {
                    Text(errorMessage)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.emergency)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Skip option (if user wants to disable)
                if biometricAuthManager.isBiometricAvailable {
                    Button(action: {
                        // Allow skip but remind them it's less secure
                        isUnlocked = true
                    }) {
                        Text("Skip for now")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                    }
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
        }
        .onAppear {
            // Auto-trigger authentication on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                authenticate()
            }
        }
    }
    
    private var biometricIcon: String {
        switch biometricAuthManager.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.fill"
        }
    }
    
    private func authenticate() {
        isAuthenticating = true
        showError = false
        
        biometricAuthManager.authenticate(
            reason: "Unlock Robot Heart",
            allowPasscode: true
        ) { success in
            isAuthenticating = false
            
            if success {
                withAnimation(.spring()) {
                    isUnlocked = true
                }
            } else {
                showError = true
                errorMessage = biometricAuthManager.authError ?? "Authentication failed"
            }
        }
    }
}

#Preview {
    BiometricLockView(isUnlocked: .constant(false))
        .environmentObject(BiometricAuthManager.shared)
}
