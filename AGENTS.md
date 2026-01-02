# AGENTS.md - Robot Heart iOS App

## Project Overview

Robot Heart is an iOS app for the Robot Heart Burning Man camp. Built on the **10 Principles of Burning Man**, it provides mesh communication, shift management, accountability tracking, safety features, and community tools for camp members.

**Repository:** https://github.com/Art-Technology-Holdings/robot-heart-ios
**Platform:** iOS 17+
**Language:** Swift 5.9+
**Framework:** SwiftUI
**Architecture:** MVVM with ObservableObject managers

## Core Philosophy

This app supports the 10 Principles:
- **Participation** - Shift/task system encourages contribution
- **Communal Effort** - Collaboration tools, shared accountability
- **Civic Responsibility** - No-shows visible, superstars recognized
- **Radical Self-reliance** - Safety check-in is opt-in
- **Immediacy** - Offline-first, "put down the phone" messaging
- **Decommodification** - Zero commerce, points can't be bought

## Tech Stack

- **UI Framework:** SwiftUI (declarative, no UIKit unless necessary)
- **State Management:** @StateObject, @EnvironmentObject, @Published
- **Persistence:** Core Data (SQLite) + UserDefaults, CloudKit sync
- **Communication:** Meshtastic (LoRa) + BLE mesh (BitChat-style) + CloudKit gateway
- **Build System:** XcodeGen (project.yml → .xcodeproj)

## Build & Run

```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build for simulator
xcodebuild -project RobotHeart.xcodeproj -scheme RobotHeart -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run tests (when available)
xcodebuild test -project RobotHeart.xcodeproj -scheme RobotHeart -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**Important:** Always run `xcodegen generate` after adding new files or modifying `project.yml`.

## Project Structure

```
RobotHeart/
├── RobotHeartApp.swift      # App entry point, all @StateObject managers
├── Models/                   # Data models (Codable structs)
├── Services/                 # Business logic managers (ObservableObject)
├── Views/                    # SwiftUI views
├── Utilities/                # Theme, extensions, helpers
└── Assets.xcassets/          # Images, colors, app icon
```

## Key Managers (Services)

| Manager | Purpose |
|---------|---------|
| `MeshtasticManager` | BLE mesh communication (LoRa) |
| `LocationManager` | GPS, ghost mode, location sharing |
| `ShiftManager` | Basic shift CRUD, notifications |
| `ShiftBlockManager` | Enhanced shifts with positions/slots |
| `EconomyManager` | Social Capital system, standings, leaderboard |
| `DraftManager` | Sports-style shift draft |
| `TaskManager` | Ad-hoc tasks with areas/priorities |
| `ProfileManager` | User profile, privacy, contact requests |
| `SocialManager` | Notes, QR exchange, events, knowledge base |
| `SocialCapitalManager` | Trust-based reputation, disaster-scale architecture |
| `EmergencyManager` | SOS, safety alerts |
| `AnnouncementManager` | Camp-wide announcements with dismiss/history |
| `CheckInManager` | Safety check-ins (opt-in by default) |
| `CampLayoutManager` | Camp layout planner with BM specs |
| `PersistenceController` | Core Data stack for offline storage |
| `LocalDataManager` | SQLite/Core Data CRUD operations |
| `BLEMeshManager` | Bluetooth peer-to-peer mesh (BitChat-style) |
| `MessageQueueManager` | Store-and-forward messaging |
| `CloudSyncManager` | CloudKit sync via gateway nodes (Starlink) |
| `CampNetworkManager` | Multi-camp protocol, camp discovery |

### Meshtastic Protocol Implementation

The app implements the full Meshtastic BLE protocol for real device communication:

**Files:**
- `MeshtasticProtocol.swift` - Protocol constants, UUIDs, packet encoding/decoding
- `MeshtasticManager.swift` - BLE connection, device discovery, message handling

**BLE Service UUID:** `6ba1b218-15a8-461f-9fa8-5dcae273eafd`

**Characteristics:**
| UUID | Name | Purpose |
|------|------|---------|
| `2c55e69e-4993-11ed-b878-0242ac120002` | FromRadio | Read packets from device |
| `f75c76d2-129e-4dad-a1dd-7866124401e7` | ToRadio | Write packets to device |
| `ed9da18c-a800-4f66-a670-aa7547e34453` | FromNum | Notifications for new data |

**Supported Devices:**
- SenseCAP T1000-E (recommended)
- RAK WisMesh Tag
- Any Meshtastic-compatible device

**Connection Flow:**
1. Scan for devices with Meshtastic service UUID
2. Connect and discover characteristics
3. Subscribe to FromNum notifications
4. Send `want_config_id` to request device config
5. Read NodeDB and radio config from FromRadio
6. Ready for messaging

## Design System (Theme.swift)

All UI must use the Theme system from `RobotHeart/Utilities/Theme.swift`:

### Colors (from STYLE_GUIDE.md)
```swift
Theme.Colors.robotCream       // #E8DCC8 - Primary text
Theme.Colors.robotBrown       // #3D2817 - Accents
Theme.Colors.sunsetOrange     // #D84315 - Primary CTA
Theme.Colors.goldenYellow     // #FFB300 - Secondary accent
Theme.Colors.turquoise        // #4ECDC4 - Active states
Theme.Colors.backgroundDark   // #1A1410 - Primary background
Theme.Colors.backgroundMedium // #2A1F1A - Cards, modals
Theme.Colors.backgroundLight  // #3A2F2A - Elevated surfaces
```

### Typography (SF Pro Rounded)
```swift
Theme.Typography.title1       // 34pt Bold
Theme.Typography.title2       // 28pt Bold
Theme.Typography.headline     // 22pt Semibold
Theme.Typography.body         // 17pt Regular
Theme.Typography.callout      // 16pt Medium
Theme.Typography.caption      // 14pt Regular
Theme.Typography.footnote     // 12pt Regular
```

### Spacing & Corners
```swift
Theme.Spacing.xs/sm/md/lg/xl/xxl  // 4/8/16/24/32/48
Theme.CornerRadius.sm/md/lg/xl   // 8/12/16/24
```

## Code Style Guidelines

### SwiftUI Views
- Use `ZStack` with `Theme.Colors.backgroundDark.ignoresSafeArea()` as root
- Prefer `NavigationView` with `.navigationBarTitleDisplayMode(.inline)`
- Use `@EnvironmentObject` for managers, not init injection
- Keep views small; extract subviews as separate structs

### Naming Conventions
- Views: `*View` suffix (e.g., `HomeView`, `TasksHubView`)
- Managers: `*Manager` suffix (e.g., `TaskManager`)
- Models: No suffix, descriptive names (e.g., `AdHocTask`, `CampMember`)
- Avoid generic names that conflict (rename if needed, e.g., `TaskStatPill` not `StatPill`)

### State Management
```swift
// In App
@StateObject private var taskManager = TaskManager()

// Pass to views
.environmentObject(taskManager)

// In views
@EnvironmentObject var taskManager: TaskManager
```

### Persistence Pattern
```swift
private let userDefaults = UserDefaults.standard
private let key = "myDataKey"

private func load() {
    if let data = userDefaults.data(forKey: key),
       let decoded = try? JSONDecoder().decode([MyType].self, from: data) {
        myData = decoded
    }
}

private func save() {
    if let encoded = try? JSONEncoder().encode(myData) {
        userDefaults.set(encoded, forKey: key)
    }
}
```

## Common Patterns

### Adding a New Feature

1. **Model** (`Models/MyFeature.swift`):
   ```swift
   struct MyModel: Identifiable, Codable {
       let id: UUID
       // properties
   }
   ```

2. **Manager** (`Services/MyManager.swift`):
   ```swift
   class MyManager: ObservableObject {
       @Published var items: [MyModel] = []
       // CRUD methods, persistence
   }
   ```

3. **View** (`Views/MyView.swift`):
   ```swift
   struct MyView: View {
       @EnvironmentObject var myManager: MyManager
       var body: some View { ... }
   }
   ```

4. **Register in App** (`RobotHeartApp.swift`):
   ```swift
   @StateObject private var myManager = MyManager()
   // ...
   .environmentObject(myManager)
   ```

5. **Regenerate project**:
   ```bash
   xcodegen generate
   ```

### Preview Provider
```swift
#Preview {
    MyView()
        .environmentObject(MyManager())
        .environmentObject(ProfileManager())
        // Add all required environment objects
}
```

## Important Constraints

### Burning Man Context
- **Offline-first:** Mesh network, no internet assumed
- **Harsh environment:** High contrast UI, large touch targets
- **Battery conscious:** Minimize background work
- **Privacy focused:** Alias system, contact request approval

### Social Capital System
| Action | Capital |
|--------|---------|
| P1 Task | +15 |
| P2 Task | +10 |
| P3 Task | +5 |
| Shift completion | Varies by type |

**Trust Levels** (based on contributions):
| Level | Contributions |
|-------|---------------|
| New | 0 |
| Improving | 1-2 |
| Contributing | 3-4 |
| Reliable | 5-9 |
| Superstar | 10-19 |
| Legendary | 20+ |

### Accountability System
- **Leaderboard shows names** - No anonymity for performance
- **No-shows visible** - Accountability for missed shifts
- **Reliability status**: Superstar, Reliable, Needs Improvement, Unreliable
- **Superstars recognized publicly** - Reward good behavior

### Privacy & Border Crossing
- **Border Crossing Mode** - Clear messages while keeping contacts & Social Capital
- **Message Retention** - Auto-delete after 24h / 7 days / 30 days / never
- **Storage Modes**: Local Only (default), Local + Encrypted Backup, Distributed (P2P)
- **Announcement Dismissal** - Clear read announcements, view history locally

### Task Areas (Default)
- Bus, Camp, Shady, Kitchen, General
- Admins can add custom areas

### Shift Locations
- Robot Heart Bus, Shady Bot, Camp

### Camp Layout (BM Specs)
- **Dimensions**: Must use 50' increments
- **Max size**: 400'×400' for established camps, 100'×100' for new
- **Fire lanes**: 20' minimum required for camps >100'×100'
- **Presets**: New Camp, Small, Medium, Large, Max Size

## Testing Instructions

Before committing:
1. Run `xcodegen generate`
2. Build: `xcodebuild -project RobotHeart.xcodeproj -scheme RobotHeart -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' build`
3. Verify no errors with: `grep -E "(error:|BUILD)" build.log`
4. Test new features manually in simulator

## Git Workflow

```bash
# Check status
git status

# Stage changes
git add <files>

# Commit with descriptive message
git commit -m "feat: Add feature description"

# Push to master
git push origin master
```

### Commit Message Format
- `feat:` New feature
- `fix:` Bug fix
- `refactor:` Code restructuring
- `docs:` Documentation
- `style:` UI/styling changes

## Security Considerations

- No hardcoded API keys
- User data stored locally in UserDefaults
- Contact info requires explicit approval to share
- Location can be hidden with "Ghost Mode"

## Known Issues / TODOs

- Camera QR scanner is placeholder (needs AVFoundation implementation)
- Calendar view in events is placeholder
- Need to implement CloudKit sync for cross-device
- Full protobuf parsing requires SwiftProtobuf library for production

## Resources

- **README.md** - User-facing documentation with features and 10 Principles
- **Style Guide:** `/STYLE_GUIDE.md`
- **Color Palette:** `/Assets/COLOR_PALETTE.md`
- **Asset Inventory:** `/Assets/ASSET_INVENTORY.md`
- **Logo Assets:** `/Assets/Logos/`
- **Photos:** `/Assets/Photos/`

---

## Documentation Maintenance (IMPORTANT)

**AI agents MUST keep documentation current.** After making significant changes:

### When to Update Documentation

1. **Adding new features** → Update README.md Features section
2. **Adding new Manager** → Update AGENTS.md Key Managers table
3. **Adding new Model** → Update Project Structure in both files
4. **Changing points/economy** → Update Points System section
5. **Changing BM compliance** → Update Camp Layout specs
6. **Adding new Views** → Update Project Structure
7. **Changing settings/preferences** → Document in relevant section

### Documentation Checklist

Before completing any task, verify:

- [ ] README.md Features section is accurate
- [ ] README.md Project Structure matches actual files
- [ ] AGENTS.md Key Managers table is complete
- [ ] AGENTS.md Points System is accurate
- [ ] Any new constraints are documented
- [ ] 10 Principles alignment is maintained

### Files to Keep in Sync

| File | Purpose | Update When |
|------|---------|-------------|
| `README.md` | User-facing docs | New features, UI changes |
| `AGENTS.md` | AI agent instructions | Code patterns, managers, constraints |
| `STYLE_GUIDE.md` | Design specs | Theme changes |
| `project.yml` | Build config | New files added |

### Verification Commands

```bash
# After any changes, always:
xcodegen generate
xcodebuild -project RobotHeart.xcodeproj -scheme RobotHeart \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

### Documentation Style

- Use tables for structured data
- Use code blocks for Swift examples
- Keep descriptions concise
- Include "At Robot Heart" context for principles
- Update timestamps/versions when relevant

---

## Contact

Repository: https://github.com/Art-Technology-Holdings/robot-heart-ios

---

*Last updated: January 2026*
*Documentation maintained by AI agents per above guidelines*
