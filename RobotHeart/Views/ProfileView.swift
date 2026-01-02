import SwiftUI
import PhotosUI

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showingEditProfile = false
    @State private var showingPrivacySettings = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Profile header
                        ProfileHeader(profile: profileManager.myProfile)
                        
                        // Quick stats
                        ProfileStats()
                        
                        // Contact requests
                        if profileManager.pendingRequestsCount > 0 {
                            ContactRequestsSection()
                        }
                        
                        // QR Connect - Exchange contact info
                        NavigationLink(destination: QRContactExchangeView()) {
                            SettingsRow(icon: "qrcode", title: "Connect via QR", color: Theme.Colors.dustyPink)
                        }
                        
                        // Edit profile link
                        NavigationLink(destination: EditProfileView()) {
                            SettingsRow(icon: "pencil.circle.fill", title: "Edit Profile", color: Theme.Colors.sunsetOrange)
                        }
                        
                        // Settings
                        NavigationLink(destination: SettingsView()) {
                            SettingsRow(icon: "gearshape.fill", title: "Settings", color: Theme.Colors.robotCream.opacity(0.7))
                        }
                        
                        // Knowledge Base / Survival Guide
                        NavigationLink(destination: KnowledgeBaseView()) {
                            SettingsRow(icon: "book.fill", title: "Survival Guide", color: Theme.Colors.goldenYellow)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Profile Header
struct ProfileHeader: View {
    let profile: UserProfile
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Profile photo
            ProfilePhotoView(imageData: profile.profilePhotoData, initials: profile.initials, size: 100)
            
            // Display name (playa name)
            Text(profile.displayName)
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.robotCream)
            
            // Real name (if visible)
            if let realName = profile.realName, profile.privacySettings.showRealName {
                Text(realName)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
            }
            
            // Home location
            if let location = profile.locationText, profile.privacySettings.showLocation {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                    Text(location)
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.sunsetOrange)
            }
            
            // Camp location
            if let campLoc = profile.campLocation, profile.privacySettings.showCampLocation {
                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "tent.fill")
                    Text(campLoc.displayText)
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.turquoise)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.lg)
    }
}

// MARK: - Profile Photo View
struct ProfilePhotoView: View {
    let imageData: Data?
    let initials: String
    let size: CGFloat
    
    var body: some View {
        ZStack {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.Colors.backgroundLight)
                    .frame(width: size, height: size)
                
                Text(initials)
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(Theme.Colors.robotCream)
            }
        }
        .overlay(
            Circle()
                .stroke(Theme.Colors.sunsetOrange, lineWidth: 3)
        )
    }
}

// MARK: - Profile Stats
struct ProfileStats: View {
    @EnvironmentObject var shiftBlockManager: ShiftBlockManager
    @EnvironmentObject var economyManager: EconomyManager
    
    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            ProfileStatItem(value: "\(economyManager.myStanding.pointsEarned)", label: "Points")
            ProfileStatItem(value: "\(shiftBlockManager.myShiftBlocks.count)", label: "Shifts")
            ProfileStatItem(value: "\(Int(economyManager.myStanding.reliabilityScore * 100))%", label: "Reliability")
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

struct ProfileStatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.Colors.sunsetOrange)
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Contact Requests Section
struct ContactRequestsSection: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var pendingRequests: [ContactRequest] {
        profileManager.contactRequests.filter { $0.status == .pending }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Contact Requests")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text("\(pendingRequests.count)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.backgroundDark)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Theme.Colors.sunsetOrange)
                    .cornerRadius(Theme.CornerRadius.full)
            }
            
            ForEach(pendingRequests) { request in
                ContactRequestRow(request: request)
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Contact Request Row
struct ContactRequestRow: View {
    @EnvironmentObject var profileManager: ProfileManager
    let request: ContactRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text(request.fromDisplayName)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Text(timeAgo(request.requestedAt))
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
            }
            
            if let message = request.message {
                Text("\"\(message)\"")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    .italic()
            }
            
            HStack(spacing: Theme.Spacing.md) {
                Button(action: { profileManager.declineContactRequest(request.id) }) {
                    Text("Decline")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.disconnected)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.backgroundLight)
                        .cornerRadius(Theme.CornerRadius.sm)
                }
                
                Button(action: { profileManager.approveContactRequest(request.id) }) {
                    Text("Share Contact")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.sm)
                        .background(Theme.Colors.connected)
                        .cornerRadius(Theme.CornerRadius.sm)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings Row
struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var displayName: String = ""
    @State private var realName: String = ""
    @State private var homeCity: String = ""
    @State private var homeCountry: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var instagram: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            Form {
                // Photo section
                Section {
                    HStack {
                        Spacer()
                        
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                ProfilePhotoView(imageData: photoData ?? profileManager.myProfile.profilePhotoData, initials: profileManager.myProfile.initials, size: 80)
                                
                                Image(systemName: "camera.circle.fill")
                                    .font(.title)
                                    .foregroundColor(Theme.Colors.sunsetOrange)
                                    .offset(x: 30, y: 30)
                            }
                        }
                        .onChange(of: selectedPhoto) { newValue in
                            Task {
                                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                    photoData = data
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Identity section
                Section {
                    TextField("Playa Name / Username", text: $displayName)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    TextField("Real Name (optional)", text: $realName)
                        .foregroundColor(Theme.Colors.robotCream)
                } header: {
                    Text("Identity")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                } footer: {
                    Text("Your playa name is always visible. Real name is private by default.")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                // Location section
                Section {
                    TextField("City", text: $homeCity)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    TextField("Country", text: $homeCountry)
                        .foregroundColor(Theme.Colors.robotCream)
                } header: {
                    Text("Home Location")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                } footer: {
                    Text("Let others know where you're from for year-round connections")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                
                // Contact section
                Section {
                    TextField("Email", text: $email)
                        .foregroundColor(Theme.Colors.robotCream)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    TextField("Phone", text: $phone)
                        .foregroundColor(Theme.Colors.robotCream)
                        .keyboardType(.phonePad)
                    
                    TextField("Instagram", text: $instagram)
                        .foregroundColor(Theme.Colors.robotCream)
                        .autocapitalization(.none)
                } header: {
                    Text("Contact Info (Private)")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                } footer: {
                    Text("Only shared with people you approve")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .foregroundColor(Theme.Colors.sunsetOrange)
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private func loadCurrentProfile() {
        displayName = profileManager.myProfile.displayName
        realName = profileManager.myProfile.realName ?? ""
        homeCity = profileManager.myProfile.homeCity ?? ""
        homeCountry = profileManager.myProfile.homeCountry ?? ""
        email = profileManager.myProfile.email ?? ""
        phone = profileManager.myProfile.phone ?? ""
        instagram = profileManager.myProfile.instagram ?? ""
    }
    
    private func saveProfile() {
        profileManager.updateDisplayName(displayName)
        profileManager.updateRealName(realName.isEmpty ? nil : realName)
        profileManager.updateHomeLocation(
            city: homeCity.isEmpty ? nil : homeCity,
            country: homeCountry.isEmpty ? nil : homeCountry
        )
        profileManager.updateContactInfo(
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            instagram: instagram.isEmpty ? nil : instagram,
            other: nil
        )
        
        if let data = photoData {
            profileManager.updateProfilePhoto(data)
        }
        
        dismiss()
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var settings: PrivacySettings = PrivacySettings()
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            Form {
                Section {
                    Toggle("Show Real Name", isOn: $settings.showRealName)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                    
                    Toggle("Show Home Location", isOn: $settings.showLocation)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                    
                    Toggle("Show Camp Location", isOn: $settings.showCampLocation)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                } header: {
                    Text("Visibility")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                }
                
                Section {
                    Toggle("Allow Contact Requests", isOn: $settings.allowContactRequests)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                    
                    Toggle("Auto-Approve Requests", isOn: $settings.autoApproveContacts)
                        .foregroundColor(Theme.Colors.robotCream)
                        .tint(Theme.Colors.sunsetOrange)
                    
                    Picker("Real Name Visible To", selection: $settings.realNameVisibility) {
                        ForEach(PrivacySettings.Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.rawValue).tag(visibility)
                        }
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                    
                    Picker("Contact Info Visible To", selection: $settings.contactVisibility) {
                        ForEach(PrivacySettings.Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.rawValue).tag(visibility)
                        }
                    }
                    .foregroundColor(Theme.Colors.robotCream)
                } header: {
                    Text("Contact Sharing")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                } footer: {
                    Text("Control who can see your real identity and contact info")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            settings = profileManager.myProfile.privacySettings
        }
        .onChange(of: settings) { newSettings in
            profileManager.updatePrivacySettings(newSettings)
        }
    }
}

// NOTE: CampMapView, StructureMarker, DraggableStructureMarker, StructureListView removed
// Camp layout functionality consolidated into CampLayoutPlannerView (CampLayoutView.swift)

// MARK: - Legacy Structure Views (kept for reference, may be removed later)
struct StructureListViewLegacy: View {
    @EnvironmentObject var profileManager: ProfileManager
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(profileManager.campMap.structures) { structure in
                    VStack(spacing: 4) {
                        Image(systemName: structure.type.icon)
                            .foregroundColor(Theme.Colors.turquoise)
                        Text(structure.name)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("\(structure.assignedMembers.count) people")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    .padding(Theme.Spacing.sm)
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.sm)
                }
            }
            .padding()
        }
        .background(Theme.Colors.backgroundDark)
    }
}

// MARK: - Add Structure View
struct AddStructureView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    let position: CGPoint
    
    @State private var name = ""
    @State private var type: CampMapStructure.StructureType = .rv
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Name (e.g., RV 5)", text: $name)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Picker("Type", selection: $type) {
                            ForEach(CampMapStructure.StructureType.allCases, id: \.self) { t in
                                Label(t.rawValue, systemImage: t.icon).tag(t)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Structure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        _ = profileManager.addStructure(
                            name: name,
                            type: type,
                            x: position.x,
                            y: position.y
                        )
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Structure Detail View
struct StructureDetailView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    @Environment(\.dismiss) var dismiss
    
    let structure: CampMapStructure
    
    var assignedMembers: [CampMember] {
        meshtasticManager.campMembers.filter { structure.assignedMembers.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: structure.type.icon)
                            .font(.system(size: 50))
                            .foregroundColor(Theme.Colors.turquoise)
                        
                        Text(structure.name)
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Text(structure.type.rawValue)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                    .padding()
                    
                    // Assigned members
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Residents (\(assignedMembers.count))")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if assignedMembers.isEmpty {
                            Text("No one assigned yet")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                        } else {
                            ForEach(assignedMembers) { member in
                                HStack {
                                    ProfilePhotoView(imageData: nil, initials: String(member.name.prefix(2)), size: 36)
                                    
                                    Text(member.name)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.robotCream)
                                    
                                    Spacer()
                                }
                                .padding(Theme.Spacing.sm)
                                .background(Theme.Colors.backgroundLight)
                                .cornerRadius(Theme.CornerRadius.sm)
                            }
                        }
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.md)
                    
                    // Set as my location
                    Button(action: {
                        profileManager.setMyCampLocation(structureID: structure.id)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text("Set as My Location")
                        }
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(structure.name)
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

#Preview {
    ProfileView()
        .environmentObject(ProfileManager())
        .environmentObject(ShiftBlockManager())
        .environmentObject(EconomyManager())
        .environmentObject(MeshtasticManager())
        .environmentObject(ShiftManager())
}
