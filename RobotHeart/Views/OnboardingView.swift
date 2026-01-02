import SwiftUI

// MARK: - Onboarding View
struct OnboardingView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentPage = 0
    @State private var displayName = ""
    @State private var homeCity = ""
    @State private var homeCountry = ""
    
    var body: some View {
        ZStack {
            // Background with sunset gradient
            Theme.Gradients.darkMode
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    WelcomePage()
                        .tag(0)
                    
                    IdentityPage(displayName: $displayName)
                        .tag(1)
                    
                    LocationPage(homeCity: $homeCity, homeCountry: $homeCountry)
                        .tag(2)
                    
                    ReadyPage()
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Navigation
                VStack(spacing: Theme.Spacing.md) {
                    // Page indicators
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(0..<4) { index in
                            Circle()
                                .fill(index == currentPage ? Theme.Colors.sunsetOrange : Theme.Colors.robotCream.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    // Next/Get Started button
                    Button(action: nextAction) {
                        Text(currentPage == 3 ? "Let's Go!" : "Continue")
                            .font(Theme.Typography.callout)
                            .foregroundColor(Theme.Colors.backgroundDark)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.Colors.sunsetOrange)
                            .cornerRadius(Theme.CornerRadius.md)
                    }
                    .disabled(currentPage == 1 && displayName.isEmpty)
                    .opacity(currentPage == 1 && displayName.isEmpty ? 0.5 : 1)
                }
                .padding()
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
    }
    
    private func nextAction() {
        if currentPage < 3 {
            withAnimation {
                currentPage += 1
            }
        } else {
            // Save profile and complete onboarding
            profileManager.updateDisplayName(displayName.isEmpty ? "Burner" : displayName)
            if !homeCity.isEmpty || !homeCountry.isEmpty {
                profileManager.updateHomeLocation(
                    city: homeCity.isEmpty ? nil : homeCity,
                    country: homeCountry.isEmpty ? nil : homeCountry
                )
            }
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Welcome Page
struct WelcomePage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            // Logo
            Image("RobotHeartLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.Colors.sunsetOrange, lineWidth: 3)
                )
            
            VStack(spacing: Theme.Spacing.md) {
                Text("Welcome to the")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                
                Text("Robot Heart Family")
                    .font(Theme.Typography.title1)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("Let's get you connected.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Identity Page
struct IdentityPage: View {
    @Binding var displayName: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.turquoise)
                
                Text("What's your playa name?")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("This is how you'll appear to other camp members. You can always change it later.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            TextField("Enter your playa name", text: $displayName)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
                .multilineTextAlignment(.center)
                .padding()
                .background(Theme.Colors.backgroundMedium)
                .cornerRadius(Theme.CornerRadius.md)
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Location Page
struct LocationPage: View {
    @Binding var homeCity: String
    @Binding var homeCountry: String
    
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.goldenYellow)
                
                Text("Where are you from?")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text("Help your camp family know where you're from for year-round connections.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: Theme.Spacing.md) {
                TextField("City", text: $homeCity)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                
                TextField("Country", text: $homeCountry)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
            }
            
            Text("Optional - you can skip this")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

// MARK: - Ready Page
struct ReadyPage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            
            // Bus photo background
            ZStack {
                Image("BusPhoto")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(Theme.CornerRadius.lg)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Theme.Colors.backgroundDark.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(Theme.CornerRadius.lg)
                    )
                
                VStack {
                    Spacer()
                    Text("You're all set!")
                        .font(Theme.Typography.title2)
                        .foregroundColor(Theme.Colors.robotCream)
                        .padding()
                }
            }
            .frame(height: 200)
            
            VStack(spacing: Theme.Spacing.md) {
                Text("Ready to connect")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    FeatureRow(icon: "calendar.badge.clock", text: "Sign up for shifts")
                    FeatureRow(icon: "person.3.fill", text: "Find your camp family")
                    FeatureRow(icon: "map.fill", text: "Navigate the playa")
                    FeatureRow(icon: "message.fill", text: "Stay connected")
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(Theme.Colors.sunsetOrange)
                .frame(width: 30)
            
            Text(text)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(ProfileManager())
}
