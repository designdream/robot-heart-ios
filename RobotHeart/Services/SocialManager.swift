import Foundation
import Combine
import CoreImage.CIFilterBuiltins

class SocialManager: ObservableObject {
    // MARK: - Published Properties
    @Published var memberNotes: [MemberNote] = []
    @Published var scannedContacts: [ScannedContact] = []
    @Published var playaEvents: [PlayaEvent] = []
    @Published var knowledgeBase: [KnowledgeArticle] = []
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let notesKey = "memberNotes"
    private let contactsKey = "scannedContacts"
    private let eventsKey = "playaEvents"
    private let articlesKey = "knowledgeBase"
    private let currentUserID = "!local"
    
    // MARK: - Initialization
    init() {
        loadAll()
        if knowledgeBase.isEmpty {
            seedKnowledgeBase()
        }
    }
    
    // MARK: - Member Notes
    func addNote(for memberID: String, content: String, tags: [String] = [], metAt: String? = nil) {
        let note = MemberNote(memberID: memberID, content: content, tags: tags, metAt: metAt)
        memberNotes.append(note)
        saveNotes()
    }
    
    func updateNote(_ noteID: UUID, content: String, tags: [String]? = nil) {
        guard let index = memberNotes.firstIndex(where: { $0.id == noteID }) else { return }
        memberNotes[index].content = content
        if let tags = tags {
            memberNotes[index].tags = tags
        }
        memberNotes[index].updatedAt = Date()
        saveNotes()
    }
    
    func deleteNote(_ noteID: UUID) {
        memberNotes.removeAll { $0.id == noteID }
        saveNotes()
    }
    
    func notes(for memberID: String) -> [MemberNote] {
        memberNotes.filter { $0.memberID == memberID }
    }
    
    // MARK: - QR Code Generation
    func generateContactCard(from profile: UserProfile) -> ContactCard {
        ContactCard(
            id: profile.id,
            displayName: profile.displayName,
            realName: profile.realName,
            homeCity: profile.homeCity,
            homeCountry: profile.homeCountry,
            email: profile.email,
            phone: profile.phone,
            instagram: profile.instagram,
            campName: "Robot Heart",
            year: Calendar.current.component(.year, from: Date()),
            createdAt: Date()
        )
    }
    
    func generateQRCode(for contactCard: ContactCard) -> CGImage? {
        guard let data = contactCard.qrData else { return nil }
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale up for better quality
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        return context.createCGImage(scaledImage, from: scaledImage.extent)
    }
    
    // MARK: - Contact Scanning
    func saveScannedContact(_ contactCard: ContactCard, note: String? = nil) {
        // Check if already scanned
        if scannedContacts.contains(where: { $0.contactCard.id == contactCard.id }) {
            return
        }
        
        let scanned = ScannedContact(contactCard: contactCard, note: note)
        scannedContacts.append(scanned)
        saveContacts()
    }
    
    func updateScannedContactNote(_ contactID: UUID, note: String) {
        guard let index = scannedContacts.firstIndex(where: { $0.id == contactID }) else { return }
        scannedContacts[index].note = note
        saveContacts()
    }
    
    func deleteScannedContact(_ contactID: UUID) {
        scannedContacts.removeAll { $0.id == contactID }
        saveContacts()
    }
    
    // MARK: - Playa Events
    func addEvent(_ event: PlayaEvent) {
        playaEvents.append(event)
        saveEvents()
    }
    
    func updateEvent(_ eventID: UUID, updates: (inout PlayaEvent) -> Void) {
        guard let index = playaEvents.firstIndex(where: { $0.id == eventID }) else { return }
        updates(&playaEvents[index])
        playaEvents[index].updatedAt = Date()
        saveEvents()
    }
    
    func deleteEvent(_ eventID: UUID) {
        playaEvents.removeAll { $0.id == eventID }
        saveEvents()
    }
    
    func toggleAttendance(_ eventID: UUID, memberID: String) {
        guard let index = playaEvents.firstIndex(where: { $0.id == eventID }) else { return }
        
        if playaEvents[index].attendees.contains(memberID) {
            playaEvents[index].attendees.removeAll { $0 == memberID }
        } else {
            playaEvents[index].attendees.append(memberID)
        }
        saveEvents()
    }
    
    var upcomingEvents: [PlayaEvent] {
        playaEvents
            .filter { $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
    }
    
    var todaysEvents: [PlayaEvent] {
        let calendar = Calendar.current
        return playaEvents
            .filter { calendar.isDateInToday($0.startTime) }
            .sorted { $0.startTime < $1.startTime }
    }
    
    func events(for category: PlayaEvent.EventCategory) -> [PlayaEvent] {
        playaEvents.filter { $0.category == category }
    }
    
    // MARK: - Knowledge Base
    func addArticle(_ article: KnowledgeArticle) {
        knowledgeBase.append(article)
        saveArticles()
    }
    
    func updateArticle(_ articleID: UUID, updates: (inout KnowledgeArticle) -> Void) {
        guard let index = knowledgeBase.firstIndex(where: { $0.id == articleID }) else { return }
        updates(&knowledgeBase[index])
        knowledgeBase[index].updatedAt = Date()
        saveArticles()
    }
    
    func deleteArticle(_ articleID: UUID) {
        knowledgeBase.removeAll { $0.id == articleID }
        saveArticles()
    }
    
    func incrementViewCount(_ articleID: UUID) {
        guard let index = knowledgeBase.firstIndex(where: { $0.id == articleID }) else { return }
        knowledgeBase[index].viewCount += 1
        saveArticles()
    }
    
    func articles(for category: KnowledgeArticle.ArticleCategory) -> [KnowledgeArticle] {
        knowledgeBase
            .filter { $0.category == category }
            .sorted { $0.isPinned && !$1.isPinned }
    }
    
    func searchArticles(_ query: String) -> [KnowledgeArticle] {
        let lowercased = query.lowercased()
        return knowledgeBase.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.content.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    var pinnedArticles: [KnowledgeArticle] {
        knowledgeBase.filter { $0.isPinned }
    }
    
    // MARK: - Persistence
    private func loadAll() {
        loadNotes()
        loadContacts()
        loadEvents()
        loadArticles()
    }
    
    private func loadNotes() {
        if let data = userDefaults.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([MemberNote].self, from: data) {
            memberNotes = decoded
        }
    }
    
    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(memberNotes) {
            userDefaults.set(encoded, forKey: notesKey)
        }
    }
    
    private func loadContacts() {
        if let data = userDefaults.data(forKey: contactsKey),
           let decoded = try? JSONDecoder().decode([ScannedContact].self, from: data) {
            scannedContacts = decoded
        }
    }
    
    private func saveContacts() {
        if let encoded = try? JSONEncoder().encode(scannedContacts) {
            userDefaults.set(encoded, forKey: contactsKey)
        }
    }
    
    private func loadEvents() {
        if let data = userDefaults.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([PlayaEvent].self, from: data) {
            playaEvents = decoded
        }
    }
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(playaEvents) {
            userDefaults.set(encoded, forKey: eventsKey)
        }
    }
    
    private func loadArticles() {
        if let data = userDefaults.data(forKey: articlesKey),
           let decoded = try? JSONDecoder().decode([KnowledgeArticle].self, from: data) {
            knowledgeBase = decoded
        }
    }
    
    private func saveArticles() {
        if let encoded = try? JSONEncoder().encode(knowledgeBase) {
            userDefaults.set(encoded, forKey: articlesKey)
        }
    }
    
    // MARK: - Seed Knowledge Base
    private func seedKnowledgeBase() {
        let articles = [
            // THE 10 PRINCIPLES - Most important, pinned first
            KnowledgeArticle(
                title: "The 10 Principles of Burning Man",
                content: """
                # The 10 Principles 🔥
                
                Written by Larry Harvey in 2004, these principles guide our community. They're not rules—they're a reflection of who we are.
                
                ---
                
                ## 1. Radical Inclusion
                Anyone may be a part of Burning Man. We welcome and respect the stranger. No prerequisites exist for participation in our community.
                
                **At Robot Heart:** Everyone is welcome at the bus. We don't judge—we dance.
                
                ---
                
                ## 2. Gifting
                Burning Man is devoted to acts of gift giving. The value of a gift is unconditional. Gifting does not contemplate a return or an exchange for something of equal value.
                
                **At Robot Heart:** The music, the experience, the community—these are our gifts. Give freely of your time, talents, and spirit.
                
                ---
                
                ## 3. Decommodification
                In order to preserve the spirit of gifting, our community seeks to create social environments that are unmediated by commercial sponsorships, transactions, or advertising.
                
                **At Robot Heart:** No money changes hands on playa. We resist the substitution of consumption for participatory experience.
                
                ---
                
                ## 4. Radical Self-reliance
                Burning Man encourages the individual to discover, exercise and rely on their inner resources.
                
                **At Robot Heart:** Bring what you need. We support each other, but you are responsible for your own survival, hydration, and well-being.
                
                ---
                
                ## 5. Radical Self-expression
                Radical self-expression arises from the unique gifts of the individual. No one other than the individual or a collaborating group can determine its content.
                
                **At Robot Heart:** Express yourself! Costumes, dance, art—be authentically you. The only limit is respecting others' experience.
                
                ---
                
                ## 6. Communal Effort
                Our community values creative cooperation and collaboration. We strive to produce, promote and protect social networks, public spaces, works of art, and methods of communication.
                
                **At Robot Heart:** The bus doesn't run without all of us. Your shifts, your participation, your presence—it all matters.
                
                ---
                
                ## 7. Civic Responsibility
                We value civil society. Community members who organize events should assume responsibility for public welfare.
                
                **At Robot Heart:** Look out for each other. If someone seems in trouble, help them or find someone who can. We are all responsible for our community's safety.
                
                ---
                
                ## 8. Leaving No Trace
                Our community respects the environment. We are committed to leaving no physical trace of our activities wherever we gather.
                
                **At Robot Heart:** MOOP matters. Pick it up. Pack it out. Leave the playa better than you found it.
                
                ---
                
                ## 9. Participation
                Our community is committed to a radically participatory ethic. We achieve being through doing. Everyone is invited to work. Everyone is invited to play.
                
                **At Robot Heart:** Don't just watch—participate! Sign up for shifts, help your campmates, dance like nobody's watching.
                
                ---
                
                ## 10. Immediacy
                Immediate experience is, in many ways, the most important touchstone of value in our culture. We seek to overcome barriers that stand between us and recognition of our inner selves.
                
                **At Robot Heart:** Put down the phone. Be present. The sunrise set isn't for Instagram—it's for your soul.
                
                ---
                
                *"The 10 Principles are not a list of commandments, but a reflection of the community's ethos."* — Larry Harvey
                """,
                category: .firstTime,
                tags: ["principles", "10 principles", "culture", "ethos", "larry harvey", "essential"],
                author: "system",
                authorName: "Burning Man"
            ),
            KnowledgeArticle(
                title: "Welcome to Robot Heart",
                content: """
                # Welcome, Dreamer! 🤖❤️
                
                You're now part of the Robot Heart family. This guide will help you navigate your first burn with us.
                
                ## What is Robot Heart?
                Robot Heart is more than an art car—it's a community of artists, dreamers, and music lovers who come together to create magic on the playa.
                
                ## The Bus
                Our iconic art car features a massive sound system and a geometric heart structure. When you hear the bass, you'll know we're nearby.
                
                ## Our Values
                We live by the 10 Principles of Burning Man. Read them. Know them. Live them.
                
                ## Camp Life
                - **Participation** - Everyone contributes through shifts
                - **Radical self-reliance** - Bring everything you need
                - **Leave no trace** - MOOP matters
                - **Communal effort** - We take care of each other
                - **Immediacy** - Be present, put down the phone
                """,
                category: .firstTime,
                tags: ["welcome", "intro", "new"],
                author: "system",
                authorName: "Robot Heart"
            ),
            KnowledgeArticle(
                title: "Playa Survival Essentials",
                content: """
                # Survival Guide 🔥
                
                ## Water
                - Minimum 1.5 gallons per person per day
                - More if you're active or it's hot
                - Electrolytes are your friend
                
                ## Dust Protection
                - Goggles (not sunglasses)
                - Bandana or dust mask
                - Saline nasal spray
                - Eye drops
                
                ## Sun Protection
                - Sunscreen SPF 50+
                - Wide-brim hat
                - Light, loose clothing
                - Seek shade during peak hours (11am-3pm)
                
                ## Night Safety
                - Lights on your body AND bike
                - Reflective gear
                - Know your camp's location by landmarks
                
                ## First Aid
                - Blister care
                - Pain relievers
                - Antacids
                - Personal medications
                """,
                category: .survival,
                tags: ["survival", "essentials", "safety", "water", "dust"],
                author: "system",
                authorName: "Robot Heart"
            ),
            KnowledgeArticle(
                title: "Shift Guide: What to Expect",
                content: """
                # Your Shift Guide 📋
                
                ## Why Shifts Matter
                Robot Heart runs on volunteer power. Your shifts keep the magic alive.
                
                ## Shift Types
                
                ### Sound & Lighting
                Help manage the audio/visual experience on the bus.
                
                ### Front Door
                Welcome guests, manage capacity, maintain vibes.
                
                ### Kitchen
                Prepare meals for camp. Cooking experience helpful.
                
                ### Strike/Build
                Set up and tear down camp infrastructure.
                
                ## Shift Etiquette
                1. **Show up on time** - Others depend on you
                2. **Stay hydrated** - Bring water to your shift
                3. **Ask questions** - No shame in learning
                4. **Have fun** - This is still Burning Man!
                
                ## Can't Make Your Shift?
                Use the app to find a trade or notify leadership ASAP.
                """,
                category: .shiftGuide,
                tags: ["shifts", "duties", "volunteer"],
                author: "system",
                authorName: "Robot Heart"
            ),
            KnowledgeArticle(
                title: "Emergency Protocols",
                content: """
                # Emergency Protocols 🚨
                
                ## Medical Emergency
                1. Stay calm
                2. Use the SOS button in the app
                3. Find a Ranger or medical personnel
                4. Camp medical team will be notified
                
                ## Lost on Playa
                - Note the nearest art installation
                - Look for the Man (center of city)
                - Head to any camp for help
                - Use the app's location features
                
                ## Dust Storm (Whiteout)
                1. STOP moving
                2. Cover your face
                3. Sit down and wait
                4. Do NOT try to navigate
                
                ## Fire
                - Alert those nearby
                - Move away from the fire
                - Find a Ranger
                - Do NOT attempt to fight large fires
                
                ## Camp Emergency Contact
                Check the app for current emergency contacts.
                """,
                category: .safety,
                tags: ["emergency", "safety", "medical", "sos"],
                author: "system",
                authorName: "Robot Heart"
            ),
            KnowledgeArticle(
                title: "Leave No Trace (MOOP)",
                content: """
                # Leave No Trace 🌍
                
                ## What is MOOP?
                Matter Out Of Place. Anything that wasn't there before we arrived.
                
                ## The Rule
                **If it hits the ground, it's MOOP.**
                
                ## Common MOOP
                - Cigarette butts
                - Feathers from costumes
                - Glitter (the herpes of craft supplies)
                - Food scraps
                - Bottle caps
                
                ## MOOP Prevention
                - Carry a MOOP bag always
                - Secure loose items
                - Avoid glitter and feathers
                - Pick up what you see
                
                ## Why It Matters
                Our permit depends on leaving the playa pristine. A bad MOOP score affects everyone.
                
                ## Camp MOOP Sweeps
                We do daily sweeps. Participate!
                """,
                category: .campDuties,
                tags: ["moop", "lnt", "leave no trace", "cleanup"],
                author: "system",
                authorName: "Robot Heart"
            )
        ]
        
        for var article in articles {
            article = KnowledgeArticle(
                title: article.title,
                content: article.content,
                category: article.category,
                tags: article.tags,
                author: article.author,
                authorName: article.authorName
            )
            knowledgeBase.append(article)
        }
        
        // Pin the 10 Principles article (most important)
        if let index = knowledgeBase.firstIndex(where: { $0.title.contains("10 Principles") }) {
            knowledgeBase[index].isPinned = true
        }
        
        // Also pin the welcome article
        if let index = knowledgeBase.firstIndex(where: { $0.title.contains("Welcome") }) {
            knowledgeBase[index].isPinned = true
        }
        
        saveArticles()
    }
}
