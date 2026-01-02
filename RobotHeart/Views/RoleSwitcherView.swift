import SwiftUI

// MARK: - Role Switcher View (Admin Only)
/// Allows admins to switch between different user roles to test the experience.
/// Accessible from Settings when logged in as admin.

struct RoleSwitcherView: View {
    @EnvironmentObject var roleManager: RoleManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    headerSection
                    
                    // Current role indicator
                    currentRoleCard
                    
                    // Role selection
                    roleSelectionSection
                    
                    // Feature preview
                    featurePreviewSection
                }
                .padding()
            }
        }
        .navigationTitle("Role Switcher")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.ledMagenta)
            
            Text("Admin Role Switcher")
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.robotCream)
            
            Text("Experience the app as different user types")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Current Role Card
    
    private var currentRoleCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack {
                Text("CURRENT VIEW")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                Spacer()
                
                if roleManager.isSimulatingRole {
                    Button("Reset to Admin") {
                        roleManager.clearSimulation()
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.turquoise)
                }
            }
            
            HStack(spacing: Theme.Spacing.md) {
                // Role icon
                ZStack {
                    Circle()
                        .fill(roleColor(roleManager.effectiveRole).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: roleManager.effectiveRole.icon)
                        .font(.title2)
                        .foregroundColor(roleColor(roleManager.effectiveRole))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(roleManager.effectiveRole.rawValue)
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if roleManager.isSimulatingRole {
                            Text("(Simulated)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.ledMagenta)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.ledMagenta.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(roleManager.effectiveRole.description)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
    
    // MARK: - Role Selection Section
    
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("SWITCH TO ROLE")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            
            ForEach(UserRole.allCases) { role in
                RoleSelectionRow(
                    role: role,
                    isSelected: roleManager.effectiveRole == role,
                    isActualRole: roleManager.actualRole == role
                ) {
                    if role == roleManager.actualRole {
                        roleManager.clearSimulation()
                    } else {
                        roleManager.simulateRole(role)
                    }
                }
            }
        }
    }
    
    // MARK: - Feature Preview Section
    
    private var featurePreviewSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("AVAILABLE FEATURES")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            
            ForEach(FeatureFlags.FeatureCategory.allCases, id: \.self) { category in
                let features = category.features.filter { roleManager.canAccess($0) }
                
                if !features.isEmpty {
                    FeatureCategoryCard(category: category, features: features)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .fan: return Theme.Colors.dustyPink
        case .volunteer: return Theme.Colors.turquoise
        case .campMember: return Theme.Colors.goldenYellow
        case .lead: return Theme.Colors.sunsetOrange
        case .admin: return Theme.Colors.ledMagenta
        }
    }
}

// MARK: - Role Selection Row

struct RoleSelectionRow: View {
    let role: UserRole
    let isSelected: Bool
    let isActualRole: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                // Role icon
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(isSelected ? 0.3 : 0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: role.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? roleColor : Theme.Colors.robotCream.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(role.rawValue)
                            .font(Theme.Typography.callout)
                            .foregroundColor(isSelected ? Theme.Colors.robotCream : Theme.Colors.robotCream.opacity(0.7))
                        
                        if isActualRole {
                            Text("(Your Role)")
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.turquoise)
                        }
                    }
                    
                    Text("\(FeatureFlags.availableFeatures(for: role).count) features")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(roleColor)
                }
            }
            .padding()
            .background(isSelected ? roleColor.opacity(0.1) : Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .stroke(isSelected ? roleColor : Color.clear, lineWidth: 1)
            )
        }
    }
    
    private var roleColor: Color {
        switch role {
        case .fan: return Theme.Colors.dustyPink
        case .volunteer: return Theme.Colors.turquoise
        case .campMember: return Theme.Colors.goldenYellow
        case .lead: return Theme.Colors.sunsetOrange
        case .admin: return Theme.Colors.ledMagenta
        }
    }
}

// MARK: - Feature Category Card

struct FeatureCategoryCard: View {
    let category: FeatureFlags.FeatureCategory
    let features: [FeatureFlags.Feature]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Theme.Colors.turquoise)
                    
                    Text(category.rawValue)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Spacer()
                    
                    Text("\(features.count)")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                .padding()
            }
            
            // Features list
            if isExpanded {
                Divider()
                    .background(Theme.Colors.robotCream.opacity(0.1))
                
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(features) { feature in
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: feature.icon)
                                .font(.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                                .frame(width: 20)
                            
                            Text(feature.rawValue)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.8))
                            
                            Spacer()
                        }
                    }
                }
                .padding()
            }
        }
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Floating Role Indicator (for testing)
/// Shows current role in a floating pill when simulating

struct FloatingRoleIndicator: View {
    @EnvironmentObject var roleManager: RoleManager
    
    var body: some View {
        if roleManager.isSimulatingRole {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: roleManager.effectiveRole.icon)
                    .font(.caption)
                
                Text("Viewing as \(roleManager.effectiveRole.rawValue)")
                    .font(Theme.Typography.caption)
                
                Button(action: { roleManager.clearSimulation() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .background(Theme.Colors.ledMagenta)
            .cornerRadius(Theme.CornerRadius.lg)
            .shadow(radius: 4)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        RoleSwitcherView()
            .environmentObject(RoleManager.previewAdmin)
    }
}
