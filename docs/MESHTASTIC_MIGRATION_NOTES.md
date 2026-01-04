# Meshtastic Service Decomposition - Migration Notes

## Overview

The Meshtastic service layer has been decomposed from a monolithic `MeshtasticManager` into 5 focused services orchestrated by `MeshtasticOrchestrator`.

## New Architecture

```
MeshtasticOrchestrator (Main entry point)
├── MeshtasticConnectionService (BLE connection management)
├── MeshtasticNodeService (Node discovery and tracking)
├── MeshtasticMessageService (Message sending/receiving)
├── MeshtasticLocationService (Location sharing)
└── MeshtasticProtocolService (Protocol buffer encoding/decoding)
```

## What's Been Completed

### ✅ Phase 1-5: Service Extraction
- Created all 5 focused services
- Created `MeshtasticOrchestrator` to coordinate services
- Updated `AppEnvironment` to use `MeshtasticOrchestrator`
- Updated `NetworkOrchestrator` to use `MeshtasticOrchestrator`

### 🔄 Phase 6: View Migration (In Progress)

The following views still reference `MeshtasticManager` and need to be updated to use `MeshtasticOrchestrator`:

1. `ContentView.swift`
2. `DraftView.swift`
3. `MapView.swift`
4. `MessagesView.swift`
5. `SettingsView.swift`
6. `CheckInView.swift`
7. `CommunityHubView.swift`
8. `ContributeView.swift`
9. `DiagnosticsView.swift`
10. `EmergencyView.swift`
11. `HomeView.swift`
12. `ProfileView.swift`
13. `RosterView.swift`
14. `ShiftView.swift`

## Migration Guide for Views

### Old Pattern
```swift
@EnvironmentObject var meshtasticManager: MeshtasticManager

// Usage
meshtasticManager.sendMessage("Hello")
meshtasticManager.isConnected
meshtasticManager.nodes
```

### New Pattern
```swift
@EnvironmentObject var appEnvironment: AppEnvironment

// Usage
try? appEnvironment.meshtastic.sendMessage("Hello")
appEnvironment.meshtastic.isConnected
appEnvironment.meshtastic.nodes.campMembers
```

### API Mapping

| Old API | New API |
|---------|---------|
| `meshtasticManager.sendMessage(_:to:)` | `meshtastic.sendMessage(_:to:)` |
| `meshtasticManager.isConnected` | `meshtastic.isConnected` |
| `meshtasticManager.nodes` | `meshtastic.nodes.campMembers` |
| `meshtasticManager.messages` | `meshtastic.messages.messages` |
| `meshtasticManager.startScanning()` | `meshtastic.startScanning()` |
| `meshtasticManager.connect(to:)` | `meshtastic.connect(to:)` |
| `meshtasticManager.disconnect()` | `meshtastic.disconnect()` |
| `meshtasticManager.enableLocationSharing()` | `meshtastic.startLocationSharing()` |
| `meshtasticManager.disableLocationSharing()` | `meshtastic.stopLocationSharing()` |

## Benefits of New Architecture

1. **Separation of Concerns**: Each service has a single, well-defined responsibility
2. **Testability**: Services can be tested in isolation
3. **Maintainability**: Easier to understand and modify individual services
4. **Scalability**: New features can be added to specific services without affecting others
5. **Reusability**: Services can be used independently or composed differently

## Testing Without Hardware

The new architecture supports testing without Meshtastic hardware:

- **Demo Members**: `MeshtasticNodeService` loads demo camp members for UI testing
- **WiFi/Cloud First**: `NetworkOrchestrator` prioritizes cloud sync when available
- **BLE Fallback**: BLE mesh works for local device-to-device testing
- **LoRa Ready**: When T1000-E devices arrive, just pair them and everything works

## Next Steps

1. **Incrementally migrate views** to use `appEnvironment.meshtastic` instead of direct `meshtasticManager`
2. **Test each view** after migration to ensure functionality is preserved
3. **Remove `MeshtasticManager.swift`** once all views are migrated
4. **Update documentation** to reflect new API patterns

## Notes

- The orchestrator pattern maintains backward compatibility at the top level
- Most method signatures remain the same, just accessed through the orchestrator
- Services communicate via callbacks set up in `MeshtasticOrchestrator.setupServiceCallbacks()`
- All services use `@MainActor` to ensure thread safety with SwiftUI

---

**Status**: Services created ✅ | Views migration 🔄 | Testing pending ⏳
