# Robot Heart iOS App 🤖❤️

A SwiftUI iOS application for Robot Heart camp at Burning Man. Built on the **10 Principles of Burning Man**, this app provides mesh communication, shift management, accountability tracking, and community tools for camp members.

## Philosophy

This app is designed to **support participation, not replace it**. It helps campers:
- Stay accountable to their commitments (shifts, tasks)
- Find each other on the playa
- Access survival knowledge
- Coordinate camp operations

**Immediacy matters** - the app encourages you to put down your phone and be present.

## Features

### 🏠 Home Dashboard
- **Social Capital** - Trust-based reputation (tap for details)
- **Announcements** - Dismissable with history (priority display)
- **Safety Check-In** (opt-in, respects autonomy)
- **Active Draft** notifications
- **My Upcoming Shifts**
- **Quick Actions** - Pull-down menu from top

### ❤️ Social Capital System
- **Trust-based reputation** - Not competitive, community-focused
- **Trust Levels**: New → Improving → Contributing → Reliable → Superstar → Legendary
- **Earned through participation** - Shifts, tasks, contributions
- **Privacy controls** - Border crossing mode, message retention settings
- **Cannot be bought** - Decommodification principle

### 📋 Shift System
- **Shift Blocks** with positions and time slots
- **Sports-Style Draft** for fair shift selection
- **Social Capital** - earn trust through participation
- **Accountability Leaderboard** - names visible, no anonymity for no-shows
- **Reliability Tracking** - Superstars recognized publicly

### ✅ Task System
- **Ad-hoc Tasks** with priorities (P1/P2/P3)
- **Task Areas**: Bus, Camp, Shady, Kitchen, General
- **Points Integration** - P1: +15, P2: +10, P3: +5
- **Claim & Complete** workflow

### 🗺️ Camp Hub
- **Roster** - All camp members with roles and status
- **Playa Map** - Location sharing with Ghost Mode
- **Camp Map** - Upload and annotate camp layout image

### 📐 Camp Layout Planner
- **BM-Compliant Sizing** - 50' increments, max 400'×400'
- **Fire Lane Validation** - 20' minimum per BM specs
- **Drag & Drop** items (RVs, tents, generators, etc.)
- **Member Assignment** - Assign campers to RVs/structures
- **Zoom & Pan** canvas with pinch gestures

### 👤 Profile & Privacy
- **Playa Name** support
- **Ghost Mode** - Hide your location
- **Contact Requests** - Approve before sharing info
- **QR Code Exchange** - Share contact cards

### 🛫 Border Crossing Mode
- **Secure your device** before crossing borders
- **Clear messages** - All DMs, group chats, announcements
- **Clear location history** - Where you've been on playa
- **Keep contacts** - Camp members and connections preserved
- **Keep Social Capital** - Your trust score stays intact
- **Keep profile** - Playa name and settings preserved
- **Restore later** - Sync from trusted peers via mesh

### 📚 Knowledge Base (Survival Guide)
- **10 Principles of Burning Man** (pinned)
- **Playa Survival Essentials**
- **Shift Guide**
- **Emergency Protocols**
- **Leave No Trace / MOOP**

### 🚨 Safety Features
- **Emergency SOS** - One-tap broadcast with location
- **Safety Check-In** - Opt-in periodic reminders
- **Announcements** - Camp-wide broadcasts with priority levels
  - Dismiss individual announcements
  - Clear all read announcements
  - View announcement history locally
  - Auto-expire old announcements

### 💬 Messages
- **Direct Messages** - Private conversations
- Mesh network messaging
- Message templates
- Store-and-forward delivery
- **Privacy Settings**:
  - Auto-delete after 24h / 7 days / 30 days / never
  - Local-only storage (default)
  - Optional encrypted backup

### Technical Features
- **Offline-first** - All data stored locally, works without internet
- **Multi-layer mesh** - BLE + Meshtastic (LoRa) + optional CloudKit
- **Store-and-forward** - Messages delivered even when recipient offline
- **Gateway nodes** - Starlink users sync data for entire network
- **End-to-end encryption** - X25519 + AES-256-GCM
- **Battery conscious** - Smart location sharing (only when moved >50m)
- **Dark mode** optimized for playa conditions
- **Large touch targets** for dusty fingers

## Architecture

Robot Heart uses a **hybrid offline-first architecture** inspired by FireChat, BitChat, and Nodle:

```
┌─────────────────────────────────────────────────────────────┐
│                    ROBOT HEART NETWORK                      │
├─────────────────────────────────────────────────────────────┤
│  Phone A ←──BLE──→ Phone B ←──BLE──→ Phone C               │
│     │                 │                 │                   │
│     └────────────────┼────────────────┘                    │
│                      ▼                                      │
│            ┌─────────────────┐                             │
│            │  LOCAL SQLITE   │  ← All data stored locally  │
│            └─────────────────┘                             │
│                      │                                      │
│     ┌────────────────┼────────────────┐                    │
│     ▼                ▼                ▼                    │
│  Meshtastic       BLE Mesh      Starlink Gateway           │
│   (LoRa)        (BitChat)        (CloudKit)                │
│  Long Range    Short Range     Cloud Backup                │
└─────────────────────────────────────────────────────────────┘
```

### Communication Layers

| Layer | Technology | Range | Use Case |
|-------|------------|-------|----------|
| **BLE Mesh** | Bluetooth Low Energy | 10-100m | In-camp messaging |
| **Meshtastic** | LoRa radio | 5-15km | Cross-playa comms |
| **CloudKit** | Apple iCloud | Global | Backup via Starlink |

### Key Innovations

- **Store-and-Forward**: Messages queue until delivered, even days later
- **Mesh Relay**: Every phone helps relay messages to extend range
- **Gateway Nodes**: Devices with Starlink sync to cloud for others
- **Multi-Camp Protocol**: Discover and communicate with other camps

📖 **Full documentation**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)  
🔒 **Security details**: [docs/SECURITY.md](docs/SECURITY.md)

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- Meshtastic device (RAK WisMesh Tag or SenseCAP T1000-E recommended)

## Setup

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate Xcode Project

```bash
cd robot-heart-app
xcodegen generate
```

### 3. Open Project

```bash
open RobotHeart.xcodeproj
```

### 4. Install Dependencies

Dependencies are managed via Swift Package Manager and will be automatically resolved:
- [Meshtastic-Apple](https://github.com/meshtastic/Meshtastic-Apple)
- [SwiftProtobuf](https://github.com/apple/swift-protobuf)

### 5. Build and Run

Select your target device and press `Cmd+R` to build and run.

## Project Structure

```
RobotHeart/
├── RobotHeartApp.swift           # App entry point, all @StateObject managers
├── Models/
│   ├── CampMember.swift          # Camp member data model
│   ├── ShiftBlock.swift          # Shift blocks with positions
│   ├── ShiftEconomy.swift        # Points system, tiers, privileges
│   ├── AdHocTask.swift           # Task system models
│   ├── CampLayoutModels.swift    # Layout planner models
│   └── ...                       # Other data models
├── Views/
│   ├── ContentView.swift         # Main tab view
│   ├── HomeView.swift            # Dashboard with announcements
│   ├── ShiftBlockView.swift      # Shift management
│   ├── TasksView.swift           # Task hub
│   ├── CampHubView.swift         # Roster, maps
│   ├── CampLayoutView.swift      # Layout planner
│   ├── EconomyView.swift         # Points & leaderboard
│   ├── SocialViews.swift         # Notes, QR, knowledge base
│   └── ...                       # Other views
├── Services/
│   ├── MeshtasticManager.swift   # BLE mesh communication
│   ├── LocationManager.swift     # GPS and location sharing
│   ├── ShiftBlockManager.swift   # Shift block logic
│   ├── EconomyManager.swift      # Points & accountability
│   ├── TaskManager.swift         # Task management
│   ├── CampLayoutManager.swift   # Layout planner logic
│   ├── ProfileManager.swift      # User profile & privacy
│   ├── SocialManager.swift       # Notes, events, knowledge
│   ├── EmergencyManager.swift    # SOS & alerts
│   ├── AnnouncementManager.swift # Camp announcements
│   ├── CheckInManager.swift      # Safety check-ins
│   └── DraftManager.swift        # Shift draft system
├── Utilities/
│   └── Theme.swift               # Design system
└── Assets.xcassets/              # Images, colors, app icon
```

## Design System

### Colors
- **Robot Cream** (#E8DCC8): Primary text and UI elements
- **Robot Brown** (#3D2817): Accents
- **Sunset Orange** (#D84315): Primary accent and CTAs
- **Golden Yellow** (#FFB300): Secondary accent
- **Turquoise** (#4ECDC4): Active states and location
- **Background Dark** (#1A1410): Main background
- **Background Medium** (#2A1F1A): Cards, modals
- **Background Light** (#3A2F2A): Elevated surfaces

### Typography
- System Rounded font family
- Optimized for one-handed operation
- Large touch targets for dusty conditions

### Animations
- Heartbeat pulse for connection status
- Smooth transitions between states
- Skeleton loaders for perceived performance

## Meshtastic Integration

### Connection Flow
1. App scans for nearby Meshtastic devices via Bluetooth
2. User selects their device from the list
3. App pairs and maintains connection
4. Messages and location updates are sent through the device to the mesh

### Message Types
- **Text**: Standard camp messages
- **Announcement**: Camp-wide broadcasts
- **Emergency**: SOS with location
- **Location Share**: GPS coordinates
- **Shift Update**: Shift change notifications

### Location Sharing
- Smart sharing: only when moved >50 meters
- Configurable interval (5-60 minutes)
- Battery-efficient with background updates
- Privacy controls per member

## Hardware Recommendations

### Personal Nodes (Each Camp Member)

**SenseCAP T1000-E** (Recommended for Robot Heart)
- Credit card size, fits in pocket
- IP65 waterproof/dustproof
- Built-in GPS (Mediatek AG3335)
- 700mAh battery (5-7 days)
- Bluetooth 5.0 (nRF52840)
- LoRa: Semtech LR1110
- ~$50-70

📖 **[T1000-E Setup Guide](docs/T1000-E_SETUP_GUIDE.md)** - Complete setup instructions

**RAK WisMesh Tag** (Alternative)
- IP66 waterproof/dustproof
- Built-in GPS
- 1000mAh battery (7+ days)
- $60-80

### Camp Base Station (Optional)
- Elevated node with solar power
- Acts as relay/repeater
- Improves mesh coverage

### Known T1000-E Issues
- LR1110 chip can't receive from older SX127x radios directly (workaround exists)
- Firmware updates via drag-and-drop may hang on v2.5.9+ (use Web Flasher)
- See [T1000-E Setup Guide](docs/T1000-E_SETUP_GUIDE.md) for all workarounds

## Development

### Mock Data
The app includes mock data for development and testing:
- Sample camp members with various roles
- Example messages with different types
- Simulated connection states

### Building for Production
1. Update bundle identifier in `project.yml`
2. Configure signing certificates
3. Update Meshtastic API keys if needed
4. Test with real Meshtastic hardware
5. Build for TestFlight or App Store

## The 10 Principles

This app is built to support the [10 Principles of Burning Man](https://burningman.org/about/10-principles/):

| Principle | How the App Supports It |
|-----------|------------------------|
| **Radical Inclusion** | Everyone visible in roster; no hierarchy |
| **Gifting** | Shifts are about giving time, not earning |
| **Decommodification** | Zero commerce; points can't be bought |
| **Radical Self-reliance** | Safety check-in is opt-in; survival guide |
| **Radical Self-expression** | Playa names; profile customization |
| **Communal Effort** | Shift system; task collaboration |
| **Civic Responsibility** | Accountability leaderboard; no-shows visible |
| **Leaving No Trace** | MOOP guide; fire lane requirements |
| **Participation** | Points for contribution; superstars recognized |
| **Immediacy** | Offline-first; "put down the phone" messaging |

## Contributing

This is a camp-specific application for Robot Heart at Burning Man. For questions or contributions, contact the camp leads.

## License

Private - Robot Heart Camp Use Only

## Acknowledgments

- Robot Heart camp and community
- Meshtastic project and contributors
- Burning Man community
- Larry Harvey and the 10 Principles

---

**Built with ❤️ for the playa**

*"We achieve being through doing."* — Participation Principle
