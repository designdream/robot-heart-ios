# Robot Heart - Camp Communication App

A SwiftUI iOS application for Robot Heart camp at Burning Man, featuring Meshtastic mesh network integration for off-grid communication, location tracking, and shift management.

## Features

### Core Functionality
- **Squad Roster**: View all camp members with real-time connection status
- **Location Sharing**: Share your location with camp mates on the playa
- **Camp Messages**: Send and receive messages over the mesh network
- **Shift Management**: Track shifts on the Robot Heart bus and Shady Bot
- **Emergency SOS**: One-tap emergency broadcast with location

### Technical Features
- Meshtastic mesh network integration via Bluetooth
- Off-grid operation (no internet required)
- Smart location sharing (only when moved >50m)
- Message templates for quick communication
- Store-and-forward message delivery
- Battery status monitoring
- Dark mode optimized for playa conditions

## Requirements

- iOS 16.0+
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
├── Models/
│   ├── CampMember.swift      # Camp member data model
│   └── Message.swift          # Message data model
├── Views/
│   ├── ContentView.swift     # Main tab view
│   ├── RosterView.swift      # Camp roster with member cards
│   ├── MapView.swift         # Location tracking map
│   ├── MessagesView.swift    # Message feed and composer
│   └── SettingsView.swift    # App settings and configuration
├── Services/
│   ├── MeshtasticManager.swift  # Meshtastic BLE communication
│   └── LocationManager.swift    # GPS and location sharing
├── Utilities/
│   └── Theme.swift           # Design system and theming
└── RobotHeartApp.swift       # App entry point
```

## Design System

### Colors
- **Robot Cream** (#E8DCC8): Primary text and UI elements
- **Robot Brown** (#3D2817): Robot features
- **Sunset Orange** (#FF6B35): Primary accent and CTAs
- **Turquoise** (#4ECDC4): Active states and location
- **Background Dark** (#1A1A1A): Main background

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
- **RAK WisMesh Tag** (Recommended)
  - IP66 waterproof/dustproof
  - Built-in GPS
  - 1000mAh battery (7+ days)
  - $60-80

- **SenseCAP Card Tracker T1000-E** (Alternative)
  - Credit card size
  - IP65 rated
  - 700mAh battery (5-7 days)
  - $50-70

### Camp Base Station (Optional)
- Elevated node with solar power
- Acts as relay/repeater
- Improves mesh coverage

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

## Contributing

This is a camp-specific application for Robot Heart at Burning Man. For questions or contributions, contact the camp leads.

## License

Private - Robot Heart Camp Use Only

## Acknowledgments

- Robot Heart camp and community
- Meshtastic project and contributors
- Burning Man community

---

**Built with ❤️ for the playa**
