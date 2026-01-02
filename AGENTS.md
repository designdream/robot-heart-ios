# AGENTS.md - Robot Heart iOS App

## Project Overview

Robot Heart is an iOS app for the Robot Heart Burning Man camp. It provides mesh communication, shift management, safety features, and community tools for camp members during the burn and year-round.

**Repository:** https://github.com/Art-Technology-Holdings/robot-heart-ios
**Platform:** iOS 17+
**Language:** Swift 5.9+
**Framework:** SwiftUI
**Architecture:** MVVM with ObservableObject managers

## Tech Stack

- **UI Framework:** SwiftUI (declarative, no UIKit unless necessary)
- **State Management:** @StateObject, @EnvironmentObject, @Published
- **Persistence:** UserDefaults (local), future: CloudKit/Firebase
- **Communication:** Meshtastic BLE mesh network (offline-first)
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
| `MeshtasticManager` | BLE mesh communication |
| `LocationManager` | GPS, ghost mode, location sharing |
| `ShiftManager` | Basic shift CRUD, notifications |
| `ShiftBlockManager` | Enhanced shifts with positions/slots |
| `EconomyManager` | Points system, standings, leaderboard |
| `DraftManager` | Sports-style shift draft |
| `TaskManager` | Ad-hoc tasks with areas/priorities |
| `ProfileManager` | User profile, privacy, contact requests |
| `SocialManager` | Notes, QR exchange, events, knowledge base |
| `EmergencyManager` | SOS, safety alerts |
| `AnnouncementManager` | Camp-wide announcements |
| `CheckInManager` | Safety check-ins |

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

### Points System
| Action | Points |
|--------|--------|
| P1 Task | +15 |
| P2 Task | +10 |
| P3 Task | +5 |
| Shift completion | Varies by type |

### Task Areas (Default)
- Bus, Camp, Shady, Kitchen, General
- Admins can add custom areas

### Shift Locations
- Robot Heart Bus, Shady Bot, Camp

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

- Meshtastic package temporarily removed (dependency issues)
- Camera QR scanner is placeholder (needs AVFoundation implementation)
- Calendar view in events is placeholder
- Need to implement CloudKit sync for cross-device

## Resources

- **Style Guide:** `/STYLE_GUIDE.md`
- **Color Palette:** `/Assets/COLOR_PALETTE.md`
- **Asset Inventory:** `/Assets/ASSET_INVENTORY.md`
- **Logo Assets:** `/Assets/Logos/`
- **Photos:** `/Assets/Photos/`

## Contact

Repository: https://github.com/Art-Technology-Holdings/robot-heart-ios
