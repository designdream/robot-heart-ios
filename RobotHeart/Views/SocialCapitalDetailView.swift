import SwiftUI

// MARK: - Social Capital Detail View
struct SocialCapitalDetailView: View {
    @EnvironmentObject var economyManager: EconomyManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Social Capital Summary
                    SocialCapitalSummaryCard()
                    
                    // Trust Level Details
                    TrustLevelCard()
                    
                    // Contribution History
                    ContributionHistoryCard()
                    
                    // How it works
                    HowSocialCapitalWorksCard()
                }
                .padding()
            }
        }
        .navigationTitle("Social Capital")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Social Capital Summary Card
struct SocialCapitalSummaryCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Big number
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.sunsetOrange)
                
                Text("\(economyManager.myStanding.pointsEarned)")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            Text("Social Capital")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Trust earned through participation")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xl)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Trust Level Card
struct TrustLevelCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    private var trustLevel: (label: String, color: Color, nextLevel: String, needed: Int) {
        let shifts = economyManager.myStanding.shiftsCompleted
        switch shifts {
        case 20...: return ("⭐ Legendary", Theme.Colors.goldenYellow, "Max Level", 0)
        case 10..<20: return ("⭐ Superstar", Theme.Colors.sunsetOrange, "Legendary", 20 - shifts)
        case 5..<10: return ("✓ Reliable", Theme.Colors.connected, "Superstar", 10 - shifts)
        case 3..<5: return ("Contributing", Theme.Colors.turquoise, "Reliable", 5 - shifts)
        case 1..<3: return ("Improving", Theme.Colors.robotCream.opacity(0.7), "Contributing", 3 - shifts)
        default: return ("New", Theme.Colors.robotCream.opacity(0.5), "Improving", 1 - shifts)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Trust Level")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text(trustLevel.label)
                    .font(Theme.Typography.callout)
                    .fontWeight(.bold)
                    .foregroundColor(trustLevel.color)
            }
            
            // Stats
            HStack(spacing: Theme.Spacing.lg) {
                SCStatItem(value: "\(economyManager.myStanding.shiftsCompleted)", label: "Shifts")
                SCStatItem(value: "\(economyManager.myStanding.pointsEarned)", label: "Capital")
                SCStatItem(value: String(format: "%.0f%%", economyManager.myStanding.reliabilityScore * 100), label: "Reliability")
            }
            
            if trustLevel.needed > 0 {
                HStack {
                    Text("\(trustLevel.needed) more contribution\(trustLevel.needed == 1 ? "" : "s") to \(trustLevel.nextLevel)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

struct SCStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.Colors.robotCream)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Contribution History Card
struct ContributionHistoryCard: View {
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recent Contributions")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            if economyManager.myStanding.shiftsCompleted == 0 {
                Text("No contributions yet. Sign up for shifts to build your Social Capital!")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    .padding(.vertical)
            } else {
                Text("Your contributions are tracked locally and shared via mesh network.")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - How Social Capital Works Card
struct HowSocialCapitalWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Theme.Colors.goldenYellow)
                
                Text("How It Works")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
            }
            
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SCHowItWorksRow(
                    icon: "calendar.badge.clock",
                    title: "Complete Shifts",
                    description: "Earn 8-20 points per shift based on difficulty"
                )
                
                SCHowItWorksRow(
                    icon: "checkmark.circle",
                    title: "Do Tasks",
                    description: "P1: +15, P2: +10, P3: +5 points"
                )
                
                SCHowItWorksRow(
                    icon: "arrow.up.circle",
                    title: "Level Up",
                    description: "More contributions = higher trust level"
                )
                
                SCHowItWorksRow(
                    icon: "heart.circle",
                    title: "Build Community",
                    description: "Your reputation helps the whole camp"
                )
            }
            
            Text("Social Capital cannot be bought - only earned through participation.")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                .italic()
                .padding(.top, Theme.Spacing.sm)
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

struct SCHowItWorksRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Theme.Colors.turquoise)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text(description)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
            }
        }
    }
}

// MARK: - Border Crossing View
struct BorderCrossingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @State private var clearMessages = true
    @State private var clearAnnouncements = true
    @State private var clearLocationHistory = true
    @State private var keepContacts = true
    @State private var keepSocialCapital = true
    @State private var showingConfirmation = false
    @State private var isClearing = false
    @State private var clearingComplete = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Warning Header
                        VStack(spacing: Theme.Spacing.md) {
                            Image(systemName: "airplane.departure")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.Colors.warning)
                            
                            Text("Border Crossing Mode")
                                .font(Theme.Typography.title2)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Text("Prepare your device for inspection. Clear sensitive data while keeping your identity and trust intact.")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        
                        // What will be cleared
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("CLEAR")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.emergency)
                            
                            ClearOptionRow(
                                icon: "message.fill",
                                title: "All Messages",
                                subtitle: "Direct messages and group chats",
                                isSelected: $clearMessages,
                                color: Theme.Colors.emergency
                            )
                            
                            ClearOptionRow(
                                icon: "megaphone.fill",
                                title: "Announcements",
                                subtitle: "Camp announcements and history",
                                isSelected: $clearAnnouncements,
                                color: Theme.Colors.emergency
                            )
                            
                            ClearOptionRow(
                                icon: "location.fill",
                                title: "Location History",
                                subtitle: "Where you've been on playa",
                                isSelected: $clearLocationHistory,
                                color: Theme.Colors.emergency
                            )
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.lg)
                        
                        // What will be kept
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("KEEP")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.connected)
                            
                            KeepOptionRow(
                                icon: "person.2.fill",
                                title: "Contacts",
                                subtitle: "Camp members and connections",
                                isKept: keepContacts,
                                color: Theme.Colors.connected
                            )
                            
                            KeepOptionRow(
                                icon: "heart.circle.fill",
                                title: "Social Capital",
                                subtitle: "Your trust and contributions",
                                isKept: keepSocialCapital,
                                color: Theme.Colors.connected
                            )
                            
                            KeepOptionRow(
                                icon: "person.fill",
                                title: "Profile",
                                subtitle: "Your playa name and settings",
                                isKept: true,
                                color: Theme.Colors.connected
                            )
                        }
                        .padding()
                        .background(Theme.Colors.backgroundMedium)
                        .cornerRadius(Theme.CornerRadius.lg)
                        
                        // Clear Button
                        if clearingComplete {
                            VStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(Theme.Colors.connected)
                                
                                Text("Device Secured")
                                    .font(Theme.Typography.headline)
                                    .foregroundColor(Theme.Colors.connected)
                                
                                Text("Safe travels! Your Social Capital and contacts are preserved.")
                                    .font(Theme.Typography.caption)
                                    .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                                    .multilineTextAlignment(.center)
                                
                                Button("Done") {
                                    dismiss()
                                }
                                .font(Theme.Typography.callout)
                                .foregroundColor(Theme.Colors.backgroundDark)
                                .padding(.horizontal, Theme.Spacing.xl)
                                .padding(.vertical, Theme.Spacing.md)
                                .background(Theme.Colors.connected)
                                .cornerRadius(Theme.CornerRadius.md)
                            }
                            .padding()
                        } else {
                            Button(action: { showingConfirmation = true }) {
                                HStack {
                                    if isClearing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "trash.fill")
                                    }
                                    Text(isClearing ? "Clearing..." : "Clear Selected Data")
                                }
                                .font(Theme.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.Colors.emergency)
                                .cornerRadius(Theme.CornerRadius.md)
                            }
                            .disabled(isClearing || (!clearMessages && !clearAnnouncements && !clearLocationHistory))
                        }
                        
                        // Tip
                        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(Theme.Colors.goldenYellow)
                            
                            Text("Tip: After crossing, you can restore messages from trusted peers via mesh sync if they still have copies.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        }
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Border Crossing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
            .alert("Clear Data?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    performClear()
                }
            } message: {
                Text("This will permanently delete the selected data. Your contacts and Social Capital will be preserved.")
            }
        }
    }
    
    private func performClear() {
        isClearing = true
        
        // Simulate clearing with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if clearMessages {
                // Clear messages from UserDefaults
                UserDefaults.standard.removeObject(forKey: "cachedMessages")
                UserDefaults.standard.removeObject(forKey: "conversations")
                meshtasticManager.messages.removeAll()
            }
            
            if clearAnnouncements {
                UserDefaults.standard.removeObject(forKey: "announcements")
                UserDefaults.standard.removeObject(forKey: "dismissedAnnouncements")
            }
            
            if clearLocationHistory {
                UserDefaults.standard.removeObject(forKey: "locationHistory")
            }
            
            isClearing = false
            clearingComplete = true
        }
    }
}

// MARK: - Clear Option Row
struct ClearOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isSelected: Bool
    let color: Color
    
    var body: some View {
        Button(action: { isSelected.toggle() }) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? color : Theme.Colors.robotCream.opacity(0.3))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.callout)
                        .foregroundColor(isSelected ? Theme.Colors.robotCream : Theme.Colors.robotCream.opacity(0.5))
                    
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : Theme.Colors.robotCream.opacity(0.3))
            }
        }
    }
}

// MARK: - Keep Option Row
struct KeepOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isKept: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Typography.callout)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            Spacer()
            
            Image(systemName: "lock.fill")
                .foregroundColor(color.opacity(0.5))
                .font(.caption)
        }
    }
}

// MARK: - SC Privacy Settings View
struct SCPrivacySettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("messageRetentionDays") private var messageRetentionDays: Int = 0
    @AppStorage("storageMode") private var storageModeRaw: String = StorageMode.localOnly.rawValue
    
    private var storageMode: StorageMode {
        StorageMode(rawValue: storageModeRaw) ?? .localOnly
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                List {
                    Section {
                        Picker("Storage Mode", selection: $storageModeRaw) {
                            ForEach(StorageMode.allCases, id: \.rawValue) { mode in
                                HStack {
                                    Image(systemName: mode.icon)
                                    Text(mode.rawValue)
                                }
                                .tag(mode.rawValue)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Data Storage")
                    } footer: {
                        Text(storageMode.description)
                    }
                    
                    Section {
                        Picker("Auto-Delete Messages", selection: $messageRetentionDays) {
                            Text("Never").tag(0)
                            Text("After 24 hours").tag(1)
                            Text("After 7 days").tag(7)
                            Text("After 30 days").tag(30)
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Message Retention")
                    } footer: {
                        Text("Messages older than this will be automatically deleted.")
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(Theme.Colors.sunsetOrange)
                            Text("Social Capital")
                            Spacer()
                            Text("Always Kept")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        }
                        
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(Theme.Colors.turquoise)
                            Text("Contacts")
                            Spacer()
                            Text("Always Kept")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        }
                    } header: {
                        Text("Protected Data")
                    } footer: {
                        Text("Your Social Capital and contacts are never automatically deleted.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Privacy Settings")
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

// MARK: - Preview
#Preview {
    NavigationView {
        SocialCapitalDetailView()
            .environmentObject(EconomyManager())
            .environmentObject(MeshtasticManager())
            .environmentObject(ProfileManager())
    }
}
