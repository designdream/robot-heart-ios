import SwiftUI
import AVFoundation

// MARK: - Member Notes View
struct MemberNotesView: View {
    @EnvironmentObject var socialManager: SocialManager
    let member: CampMember
    
    @State private var showingAddNote = false
    @State private var newNoteContent = ""
    @State private var newNoteTags = ""
    @State private var metAt = ""
    
    var notes: [MemberNote] {
        socialManager.notes(for: member.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Private Notes")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.robotCream)
                
                Spacer()
                
                Button(action: { showingAddNote = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
            
            if notes.isEmpty {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                    Text("No notes yet")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
                .padding()
            } else {
                ForEach(notes) { note in
                    NoteCard(note: note)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
        .sheet(isPresented: $showingAddNote) {
            AddNoteSheet(
                memberName: member.name,
                content: $newNoteContent,
                tags: $newNoteTags,
                metAt: $metAt,
                onSave: {
                    let tagArray = newNoteTags.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                    socialManager.addNote(
                        for: member.id,
                        content: newNoteContent,
                        tags: tagArray,
                        metAt: metAt.isEmpty ? nil : metAt
                    )
                    newNoteContent = ""
                    newNoteTags = ""
                    metAt = ""
                    showingAddNote = false
                }
            )
        }
    }
}

// MARK: - Note Card
struct NoteCard: View {
    @EnvironmentObject var socialManager: SocialManager
    let note: MemberNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(note.content)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.robotCream)
            
            if let metAt = note.metAt {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.caption2)
                    Text("Met at: \(metAt)")
                }
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.turquoise)
            }
            
            if !note.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.xs) {
                        ForEach(note.tags, id: \.self) { tag in
                            Text(tag)
                                .font(Theme.Typography.footnote)
                                .foregroundColor(Theme.Colors.backgroundDark)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(Theme.Colors.goldenYellow)
                                .cornerRadius(Theme.CornerRadius.full)
                        }
                    }
                }
            }
            
            HStack {
                Text(note.updatedAt, style: .relative)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
                
                Spacer()
                
                Button(action: { socialManager.deleteNote(note.id) }) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.disconnected.opacity(0.6))
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    let memberName: String
    @Binding var content: String
    @Binding var tags: String
    @Binding var metAt: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Note about \(memberName)")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        TextField("Where did you meet?", text: $metAt)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Met At")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        TextField("Tags (comma separated)", text: $tags)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Tags")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    } footer: {
                        Text("e.g., artist, DJ, follow up")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: onSave)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                        .disabled(content.isEmpty)
                }
            }
        }
    }
}

// MARK: - QR Contact Exchange View
struct QRContactExchangeView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var socialManager: SocialManager
    
    @State private var showingScanner = false
    @State private var qrImage: CGImage?
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // My QR Code
                    VStack(spacing: Theme.Spacing.md) {
                        Text("My Contact Card")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if let qrImage = qrImage {
                            Image(decorative: qrImage, scale: 1)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(Theme.CornerRadius.md)
                        } else {
                            ProgressView()
                                .frame(width: 200, height: 200)
                        }
                        
                        Text(profileManager.myProfile.displayName)
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        if let location = profileManager.myProfile.locationText {
                            Text(location)
                                .font(Theme.Typography.caption)
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                        }
                        
                        Text("Show this to exchange contact info")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    .padding()
                    .background(Theme.Colors.backgroundMedium)
                    .cornerRadius(Theme.CornerRadius.lg)
                    
                    // Scan Button
                    Button(action: { showingScanner = true }) {
                        HStack {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Scan Someone's Code")
                        }
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.backgroundDark)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.Colors.sunsetOrange)
                        .cornerRadius(Theme.CornerRadius.md)
                    }
                    
                    // Scanned Contacts
                    if !socialManager.scannedContacts.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Scanned Contacts (\(socialManager.scannedContacts.count))")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            ForEach(socialManager.scannedContacts) { contact in
                                ScannedContactCard(contact: contact)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Contact Exchange")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            generateQR()
        }
        .sheet(isPresented: $showingScanner) {
            QRScannerView { result in
                handleScan(result)
                showingScanner = false
            }
        }
    }
    
    private func generateQR() {
        let card = socialManager.generateContactCard(from: profileManager.myProfile)
        qrImage = socialManager.generateQRCode(for: card)
    }
    
    private func handleScan(_ data: Data) {
        if let card = ContactCard.from(data: data) {
            socialManager.saveScannedContact(card)
        }
    }
}

// MARK: - Scanned Contact Card
struct ScannedContactCard: View {
    @EnvironmentObject var socialManager: SocialManager
    let contact: ScannedContact
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.contactCard.displayName)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if let realName = contact.contactCard.realName {
                        Text(realName)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                }
                
                Spacer()
                
                Text(contact.scannedAt, style: .date)
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
            
            // Contact info
            HStack(spacing: Theme.Spacing.md) {
                if contact.contactCard.instagram != nil {
                    Image(systemName: "camera.fill")
                        .foregroundColor(Theme.Colors.dustyPink)
                }
                if contact.contactCard.email != nil {
                    Image(systemName: "envelope.fill")
                        .foregroundColor(Theme.Colors.turquoise)
                }
                if contact.contactCard.phone != nil {
                    Image(systemName: "phone.fill")
                        .foregroundColor(Theme.Colors.connected)
                }
                
                Spacer()
                
                if let city = contact.contactCard.homeCity {
                    HStack(spacing: 2) {
                        Image(systemName: "mappin")
                        Text(city)
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.goldenYellow)
                }
            }
            .font(.caption)
            
            if let note = contact.note {
                Text(note)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    .italic()
            }
        }
        .padding()
        .background(Theme.Colors.backgroundLight)
        .cornerRadius(Theme.CornerRadius.sm)
    }
}

// MARK: - QR Scanner View (Placeholder)
struct QRScannerView: View {
    let onScan: (Data) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 100))
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    
                    Text("Point camera at QR code")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    Text("Camera access required")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    
                    // In production, this would be a real camera view
                    // For now, show a placeholder
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                        .stroke(Theme.Colors.sunsetOrange, lineWidth: 2)
                        .frame(width: 250, height: 250)
                        .overlay(
                            Text("Camera Preview")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                        )
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
            }
        }
    }
}

// MARK: - Knowledge Base View
struct KnowledgeBaseView: View {
    @EnvironmentObject var socialManager: SocialManager
    @State private var searchText = ""
    @State private var selectedCategory: KnowledgeArticle.ArticleCategory?
    
    var filteredArticles: [KnowledgeArticle] {
        var articles = socialManager.knowledgeBase
        
        if let category = selectedCategory {
            articles = articles.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            articles = socialManager.searchArticles(searchText)
        }
        
        return articles.sorted { 
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.viewCount > $1.viewCount
        }
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    
                    TextField("Search guides...", text: $searchText)
                        .foregroundColor(Theme.Colors.robotCream)
                }
                .padding()
                .background(Theme.Colors.backgroundMedium)
                
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(KnowledgeArticle.ArticleCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding()
                }
                
                // Articles
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        // Pinned section
                        if selectedCategory == nil && searchText.isEmpty {
                            let pinned = socialManager.pinnedArticles
                            if !pinned.isEmpty {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    Text("📌 Essential Reading")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.goldenYellow)
                                    
                                    ForEach(pinned) { article in
                                        NavigationLink(destination: ArticleDetailView(article: article)) {
                                            ArticleCard(article: article)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        ForEach(filteredArticles.filter { !$0.isPinned || selectedCategory != nil || !searchText.isEmpty }) { article in
                            NavigationLink(destination: ArticleDetailView(article: article)) {
                                ArticleCard(article: article)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("Survival Guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    var icon: String? = nil
    var color: Color = Theme.Colors.sunsetOrange
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(Theme.Typography.caption)
            }
            .foregroundColor(isSelected ? Theme.Colors.backgroundDark : Theme.Colors.robotCream)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(isSelected ? color : Theme.Colors.backgroundLight)
            .cornerRadius(Theme.CornerRadius.full)
        }
    }
}

// MARK: - Article Card
struct ArticleCard: View {
    let article: KnowledgeArticle
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Category icon
            Image(systemName: article.category.icon)
                .font(.title2)
                .foregroundColor(article.category.color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if article.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(Theme.Colors.goldenYellow)
                    }
                    
                    Text(article.title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                        .lineLimit(1)
                }
                
                Text(article.category.rawValue)
                    .font(Theme.Typography.caption)
                    .foregroundColor(article.category.color)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.3))
                
                Text("\(article.viewCount) views")
                    .font(Theme.Typography.footnote)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.4))
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Article Detail View
struct ArticleDetailView: View {
    @EnvironmentObject var socialManager: SocialManager
    let article: KnowledgeArticle
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Image(systemName: article.category.icon)
                                .foregroundColor(article.category.color)
                            Text(article.category.rawValue)
                                .font(Theme.Typography.caption)
                                .foregroundColor(article.category.color)
                        }
                        
                        Text(article.title)
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        HStack {
                            Text("By \(article.authorName)")
                            Text("•")
                            Text(article.updatedAt, style: .date)
                        }
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    
                    Divider()
                        .background(Theme.Colors.robotCream.opacity(0.2))
                    
                    // Content (simplified markdown rendering)
                    Text(article.content)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                        .lineSpacing(6)
                    
                    // Tags
                    if !article.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.xs) {
                                ForEach(article.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.turquoise)
                                        .padding(.horizontal, Theme.Spacing.sm)
                                        .padding(.vertical, 4)
                                        .background(Theme.Colors.backgroundLight)
                                        .cornerRadius(Theme.CornerRadius.sm)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            socialManager.incrementViewCount(article.id)
        }
    }
}

// MARK: - Playa Events View
struct PlayaEventsView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var profileManager: ProfileManager
    @State private var selectedCategory: PlayaEvent.EventCategory?
    @State private var showingAddEvent = false
    @State private var viewMode: ViewMode = .list
    
    enum ViewMode {
        case list, calendar
    }
    
    var filteredEvents: [PlayaEvent] {
        var events = socialManager.upcomingEvents
        if let category = selectedCategory {
            events = events.filter { $0.category == category }
        }
        return events
    }
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // View mode toggle
                Picker("View", selection: $viewMode) {
                    Text("List").tag(ViewMode.list)
                    Text("Calendar").tag(ViewMode.calendar)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(PlayaEvent.EventCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                color: category.color,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Events
                if viewMode == .list {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            // Today's events
                            if !socialManager.todaysEvents.isEmpty && selectedCategory == nil {
                                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                                    Text("🔥 Happening Today")
                                        .font(Theme.Typography.caption)
                                        .foregroundColor(Theme.Colors.sunsetOrange)
                                    
                                    ForEach(socialManager.todaysEvents) { event in
                                        EventCard(event: event)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // All events
                            ForEach(filteredEvents) { event in
                                EventCard(event: event)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    // Calendar view placeholder
                    VStack {
                        Text("Calendar View")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.robotCream)
                        Text("Coming soon")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Playa Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEvent = true }) {
                    Image(systemName: "plus")
                        .foregroundColor(Theme.Colors.sunsetOrange)
                }
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView()
        }
    }
}

// MARK: - Event Card
struct EventCard: View {
    @EnvironmentObject var socialManager: SocialManager
    let event: PlayaEvent
    
    private let currentUserID = "!local"
    
    var isAttending: Bool {
        event.attendees.contains(currentUserID)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: event.category.icon)
                    .foregroundColor(event.category.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.robotCream)
                    
                    if let host = event.hostCamp {
                        Text("by \(host)")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.6))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.startTime, style: .time)
                        .font(Theme.Typography.callout)
                        .foregroundColor(Theme.Colors.sunsetOrange)
                    
                    Text(event.startTime, style: .date)
                        .font(Theme.Typography.footnote)
                        .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                }
            }
            
            HStack {
                Image(systemName: "mappin")
                Text(event.location.displayText)
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.turquoise)
            
            HStack {
                Text("\(event.attendees.count) going")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                
                Spacer()
                
                Button(action: {
                    socialManager.toggleAttendance(event.id, memberID: currentUserID)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isAttending ? "checkmark.circle.fill" : "plus.circle")
                        Text(isAttending ? "Going" : "Join")
                    }
                    .font(Theme.Typography.caption)
                    .foregroundColor(isAttending ? Theme.Colors.connected : Theme.Colors.sunsetOrange)
                }
            }
        }
        .padding()
        .background(Theme.Colors.backgroundMedium)
        .cornerRadius(Theme.CornerRadius.md)
    }
}

// MARK: - Add Event View
struct AddEventView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var profileManager: ProfileManager
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var locationName = ""
    @State private var clockPosition = ""
    @State private var street = ""
    @State private var startTime = Date()
    @State private var category: PlayaEvent.EventCategory = .community
    @State private var hostCamp = "Robot Heart"
    @State private var isPublic = true
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.backgroundDark.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Event Title", text: $title)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .foregroundColor(Theme.Colors.robotCream)
                    } header: {
                        Text("Details")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        TextField("Location Name", text: $locationName)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        HStack {
                            TextField("Clock (e.g., 2:00)", text: $clockPosition)
                                .foregroundColor(Theme.Colors.robotCream)
                            
                            Text("&")
                                .foregroundColor(Theme.Colors.robotCream.opacity(0.5))
                            
                            TextField("Street", text: $street)
                                .foregroundColor(Theme.Colors.robotCream)
                        }
                    } header: {
                        Text("Location")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                    
                    Section {
                        DatePicker("Start Time", selection: $startTime)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Picker("Category", selection: $category) {
                            ForEach(PlayaEvent.EventCategory.allCases, id: \.self) { cat in
                                Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                            }
                        }
                        .foregroundColor(Theme.Colors.robotCream)
                        
                        TextField("Host Camp", text: $hostCamp)
                            .foregroundColor(Theme.Colors.robotCream)
                        
                        Toggle("Public Event", isOn: $isPublic)
                            .foregroundColor(Theme.Colors.robotCream)
                            .tint(Theme.Colors.sunsetOrange)
                    } header: {
                        Text("Event Info")
                            .foregroundColor(Theme.Colors.robotCream.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.robotCream)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEvent()
                    }
                    .foregroundColor(Theme.Colors.sunsetOrange)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func createEvent() {
        let location = PlayaEvent.EventLocation(
            name: locationName.isEmpty ? "TBD" : locationName,
            clockPosition: clockPosition.isEmpty ? nil : clockPosition,
            street: street.isEmpty ? nil : street
        )
        
        let event = PlayaEvent(
            title: title,
            description: description,
            location: location,
            startTime: startTime,
            category: category,
            hostCamp: hostCamp.isEmpty ? nil : hostCamp,
            createdBy: "!local",
            createdByName: profileManager.myProfile.displayName,
            isPublic: isPublic
        )
        
        socialManager.addEvent(event)
        dismiss()
    }
}
