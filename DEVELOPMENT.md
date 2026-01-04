# Robot Heart App - Development Guide

## Quick Start

### Prerequisites
- macOS with Xcode 15.0+
- Homebrew installed
- Git configured

### Initial Setup

1. **Clone the repository**
```bash
git clone https://github.com/designdream/robot-heart-ios.git
cd robot-heart-ios
```

2. **Install XcodeGen**
```bash
brew install xcodegen
```

3. **Generate Xcode project**
```bash
xcodegen generate
```

4. **Open in Xcode**
```bash
open RobotHeart.xcodeproj
```

5. **Build and run**
- Select a simulator or device
- Press `Cmd+R` to build and run

## Project Architecture

### MVVM Pattern
The app follows the Model-View-ViewModel pattern:

- **Models**: Data structures (`CampMember`, `Message`)
- **Views**: SwiftUI views (`RosterView`, `MapView`, etc.)
- **ViewModels**: Business logic in `@ObservableObject` classes (`MeshtasticManager`, `LocationManager`)

### Key Components

#### MeshtasticManager
Handles all Meshtastic device communication:
- Bluetooth scanning and connection
- Message sending/receiving
- Node database management
- Connection status

#### LocationManager
Manages GPS and location sharing:
- Core Location integration
- Smart location updates (movement-based)
- Background location tracking
- Privacy controls

#### Theme System
Centralized design system in `Theme.swift`:
- Colors (Robot Heart branding)
- Typography (SF Rounded)
- Spacing and layout constants
- Animation presets

## Development Workflow

### Making Changes

1. **Create a feature branch**
```bash
git checkout -b feature/your-feature-name
```

2. **Make your changes**
- Edit Swift files
- Test in simulator
- Update documentation if needed

3. **Regenerate project if needed**
```bash
xcodegen generate
```

4. **Commit and push**
```bash
git add .
git commit -m "Description of changes"
git push origin feature/your-feature-name
```

### Testing with Real Hardware

#### Meshtastic Device Setup
1. Purchase a RAK WisMesh Tag or SenseCAP T1000-E
2. Flash with latest Meshtastic firmware
3. Configure device settings:
   - Set region to US (915 MHz)
   - Enable Bluetooth
   - Set device name
   - Configure channel PSK for camp privacy

4. Pair with iPhone:
   - Enable Bluetooth on iPhone
   - Open Robot Heart app
   - Go to Settings → Scan for Devices
   - Select your device

#### Testing Location Sharing
1. Enable location permissions in iOS Settings
2. Start location sharing in the app
3. Move around to trigger updates
4. Verify location appears on map for other users

## Adding New Features

### Adding a New View

1. Create new Swift file in `RobotHeart/Views/`
2. Import SwiftUI
3. Create struct conforming to `View`
4. Use Theme system for styling
5. Add to navigation if needed

Example:
```swift
import SwiftUI

struct NewFeatureView: View {
    @EnvironmentObject var meshtasticManager: MeshtasticManager
    
    var body: some View {
        ZStack {
            Theme.Colors.backgroundDark.ignoresSafeArea()
            
            VStack {
                Text("New Feature")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.robotCream)
            }
        }
    }
}
```

### Adding a New Model

1. Create new Swift file in `RobotHeart/Models/`
2. Make it `Identifiable` and `Codable`
3. Add mock data for testing

Example:
```swift
struct NewModel: Identifiable, Codable {
    let id: String
    var name: String
    var timestamp: Date
    
    static let mockData: [NewModel] = [
        NewModel(id: "1", name: "Test", timestamp: Date())
    ]
}
```

### Modifying the Theme

Edit `RobotHeart/Utilities/Theme.swift`:

```swift
// Add new color
static let newColor = Color(hex: "FF5733")

// Add new typography style
static let customStyle = Font.system(size: 20, weight: .medium, design: .rounded)

// Add new animation
static let customAnimation = Animation.spring(response: 0.5, dampingFraction: 0.7)
```

## Meshtastic Integration

### Message Flow

1. User composes message in app
2. App sends to `MeshtasticManager`
3. Manager encodes as protobuf
4. Sent via Bluetooth to Meshtastic device
5. Device broadcasts on LoRa mesh
6. Other devices receive and forward
7. Recipients' apps decode and display

### Adding New Message Types

1. Add case to `Message.MessageType` enum
2. Define icon and color
3. Add template if needed
4. Update message handling in `MeshtasticManager`

### Location Packet Format

Location updates use Meshtastic's position packet:
```swift
struct LocationPacket {
    latitude: Double
    longitude: Double
    altitude: Int
    timestamp: UInt32
    precision: UInt8
}
```

## Performance Optimization

### Battery Life
- Use smart location updates (movement-based)
- Reduce Bluetooth polling frequency
- Batch message sends when possible
- Use background modes efficiently

### Memory Management
- Limit message history (keep last 100)
- Lazy load member list
- Release unused resources
- Use weak references in closures

### Network Efficiency
- Compress location data
- Use protobuf for efficient serialization
- Implement message deduplication
- Respect mesh bandwidth limits

## Debugging

### Common Issues

**Bluetooth not connecting:**
- Check iOS Bluetooth permissions
- Verify Meshtastic device is powered on
- Ensure device is in range (<30 feet)
- Try resetting Bluetooth on iPhone

**Location not updating:**
- Check location permissions (Always)
- Verify GPS signal (may be weak indoors)
- Check movement threshold (50m default)
- Review location sharing settings

**Messages not sending:**
- Verify Bluetooth connection
- Check mesh network status
- Ensure device has battery
- Review message queue status

### Debug Logging

Add print statements for debugging:
```swift
print("🔵 [Meshtastic] Sending message: \(message.content)")
print("📍 [Location] Updated: \(location.coordinate)")
print("⚡️ [Battery] Level: \(batteryLevel)%")
```

### Xcode Debugging
- Set breakpoints in key functions
- Use LLDB console for inspection
- Monitor memory graph for leaks
- Profile with Instruments

## Deployment

### TestFlight

1. Archive the app in Xcode
2. Upload to App Store Connect
3. Add internal testers (camp members)
4. Distribute build
5. Collect feedback

### App Store (Future)

1. Prepare marketing materials
2. Create app screenshots
3. Write app description
4. Submit for review
5. Monitor analytics

## Resources

- [Meshtastic Documentation](https://meshtastic.org/docs/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Core Location Guide](https://developer.apple.com/documentation/corelocation)
- [XcodeGen Documentation](https://github.com/yonaskolb/XcodeGen)

## Support

For questions or issues:
- Create GitHub issue
- Contact camp tech lead
- Check Meshtastic Discord

---

**Happy coding! See you on the playa! 🤖❤️**
