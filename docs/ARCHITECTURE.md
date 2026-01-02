# Robot Heart Architecture

## Overview

Robot Heart implements an **offline-first, peer-to-peer communication system** designed for environments with no internet connectivity—specifically Burning Man's Black Rock Desert. The architecture draws inspiration from:

- **FireChat** (2014-2018) - Bluetooth mesh messaging used in Hong Kong protests
- **BitChat** (Jack Dorsey, 2025) - BLE mesh with store-and-forward
- **Nodle Network** - Smartphone-based IoT mesh with proof of connectivity
- **Meshtastic** - LoRa long-range mesh networking

## Design Principles

1. **Offline-First**: All data stored locally before any network transmission
2. **Store-and-Forward**: Messages persist until delivered, even days later
3. **Mesh Relay**: Every device helps relay messages to extend range
4. **Gateway Nodes**: Devices with internet (Starlink) sync to cloud for others
5. **Privacy by Design**: End-to-end encryption, local-first storage
6. **Resilience**: No single point of failure, works in harsh conditions

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         ROBOT HEART NETWORK                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│    ┌──────────┐         ┌──────────┐         ┌──────────┐              │
│    │ Phone A  │◄──BLE──►│ Phone B  │◄──BLE──►│ Phone C  │              │
│    │(Sender)  │         │ (Relay)  │         │(Receiver)│              │
│    └────┬─────┘         └────┬─────┘         └────┬─────┘              │
│         │                    │                    │                     │
│         ▼                    ▼                    ▼                     │
│    ┌─────────────────────────────────────────────────────┐             │
│    │              LOCAL SQLITE DATABASE                   │             │
│    │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │             │
│    │  │  Messages   │ │   Members   │ │    Camps    │   │             │
│    │  │  (cached)   │ │  (cached)   │ │  (cached)   │   │             │
│    │  └─────────────┘ └─────────────┘ └─────────────┘   │             │
│    │  ┌─────────────┐ ┌─────────────┐                   │             │
│    │  │  Pending    │ │  Sync Queue │                   │             │
│    │  │  Messages   │ │  (for cloud)│                   │             │
│    │  └─────────────┘ └─────────────┘                   │             │
│    └─────────────────────────────────────────────────────┘             │
│                              │                                          │
│         ┌────────────────────┼────────────────────┐                    │
│         ▼                    ▼                    ▼                    │
│    ┌──────────┐        ┌──────────┐        ┌──────────┐               │
│    │Meshtastic│        │ BLE Mesh │        │ CloudKit │               │
│    │  (LoRa)  │        │(BitChat) │        │ Gateway  │               │
│    │ 5-15 km  │        │ 10-100m  │        │(Starlink)│               │
│    └──────────┘        └──────────┘        └──────────┘               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Communication Layers

### Layer 1: Bluetooth Low Energy (BLE) Mesh

**Range:** 10-100 meters  
**Bandwidth:** ~1 Mbps  
**Use Case:** In-camp communication, peer discovery

```swift
// BLE Service UUID (Robot Heart specific)
static let serviceUUID = CBUUID(string: "RH01B218-15A8-461F-9FA8-5DCAE273EAFD")

// Characteristics
static let messageCharacteristicUUID = CBUUID(string: "RH02C69E-4993-11ED-B878-0242AC120002")
static let presenceCharacteristicUUID = CBUUID(string: "RH03D6D2-129E-4DAD-A1DD-7866124401E7")
```

**How it works:**
1. Each phone advertises as a BLE peripheral with Robot Heart service UUID
2. Each phone also scans for other peripherals (central role)
3. When peers discover each other, they connect and exchange messages
4. Messages are relayed to other connected peers (mesh behavior)

### Layer 2: Meshtastic (LoRa)

**Range:** 5-15 km typical, up to 331 km record  
**Bandwidth:** ~200 bytes per message  
**Use Case:** Cross-playa communication, emergency alerts

```swift
// Meshtastic BLE Service UUID
static let meshtasticServiceUUID = CBUUID(string: "6ba1b218-15a8-461f-9fa8-5dcae273eafd")

// Supported PortNums
TEXT_MESSAGE_APP = 1      // Text messages
POSITION_APP = 3          // GPS location
NODEINFO_APP = 4          // User info
PRIVATE_APP = 256         // Robot Heart protocol
```

**How it works:**
1. Phone connects to Meshtastic device via BLE
2. Messages encoded as protobuf, sent to device
3. Device broadcasts over LoRa radio
4. Other Meshtastic devices receive and relay
5. Eventually reaches recipient's phone

### Layer 3: CloudKit Gateway

**Range:** Global (when internet available)  
**Bandwidth:** Unlimited  
**Use Case:** Backup, cross-network sync, post-event access

**How it works:**
1. App detects WiFi/Ethernet connection (e.g., Starlink)
2. Device becomes a "Gateway Node"
3. Gateway uploads local messages to CloudKit
4. Gateway downloads messages from cloud, relays to mesh
5. Non-gateway devices benefit from cloud sync indirectly

---

## Data Flow

### Sending a Message

```
┌─────────────────────────────────────────────────────────────────┐
│                    MESSAGE SEND FLOW                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. User types message                                          │
│         │                                                       │
│         ▼                                                       │
│  2. Save to LOCAL DATABASE (offline-first)                      │
│         │                                                       │
│         ├──────────────────────────────────────┐               │
│         ▼                                      ▼               │
│  3. Add to PENDING QUEUE              4. Add to SYNC QUEUE     │
│     (for delivery)                       (for cloud backup)    │
│         │                                                       │
│         ▼                                                       │
│  5. Attempt IMMEDIATE DELIVERY via:                             │
│     ├─► BLE Mesh (nearby peers)                                │
│     └─► Meshtastic (if connected)                              │
│         │                                                       │
│         ▼                                                       │
│  6. If delivery fails → RETRY with exponential backoff         │
│     (30s, 45s, 67s, 101s... up to 10 attempts)                 │
│         │                                                       │
│         ▼                                                       │
│  7. On DELIVERY CONFIRMATION → Remove from pending queue       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Receiving a Message

```
┌─────────────────────────────────────────────────────────────────┐
│                   MESSAGE RECEIVE FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Message arrives via BLE/Meshtastic                          │
│         │                                                       │
│         ▼                                                       │
│  2. Check: Have we seen this message ID before?                 │
│         │                                                       │
│         ├─► YES: Ignore (prevent loops)                        │
│         │                                                       │
│         ▼ NO                                                    │
│  3. Check: Is this message for us?                              │
│         │                                                       │
│         ├─► NO: RELAY to other peers (mesh behavior)           │
│         │                                                       │
│         ▼ YES                                                   │
│  4. Save to LOCAL DATABASE                                      │
│         │                                                       │
│         ▼                                                       │
│  5. Send DELIVERY CONFIRMATION back to sender                   │
│         │                                                       │
│         ▼                                                       │
│  6. Post NOTIFICATION to UI                                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Store-and-Forward System

The store-and-forward system ensures messages are delivered even when the recipient is offline or out of range.

### Pending Message Queue

```swift
struct PendingMessage {
    let id: UUID
    let recipientID: String
    let encryptedPayload: Data
    let messageType: String
    var status: String          // "pending", "delivered", "failed"
    var attempts: Int           // 0-10
    let createdAt: Date
    var lastAttempt: Date?
}
```

### Retry Logic

| Attempt | Delay | Cumulative Time |
|---------|-------|-----------------|
| 1 | 30s | 30s |
| 2 | 45s | 1m 15s |
| 3 | 67s | 2m 22s |
| 4 | 101s | 4m 3s |
| 5 | 152s | 6m 35s |
| 6 | 228s | 10m 23s |
| 7 | 342s | 16m 5s |
| 8 | 513s | 24m 38s |
| 9 | 769s | 37m 27s |
| 10 | 1154s | 56m 41s |

After 10 failed attempts (~1 hour), the message is marked as "failed" but remains in local storage.

---

## Multi-Camp Protocol

Robot Heart supports communication between multiple Burning Man camps using a standardized protocol.

### Protocol Message Format

```swift
struct CampProtocolMessage: Codable {
    let version: UInt8              // Protocol version (currently 1)
    let type: MessageType           // ping, announce, chat, resource, event, emergency
    let campID: String              // UUID of sending camp
    let senderID: String            // UUID of sending user
    let timestamp: Date
    let payload: Data?              // Type-specific payload
}
```

### Message Types

| Type | Purpose | Payload |
|------|---------|---------|
| `ping` | Discover nearby camps | None |
| `announce` | Broadcast camp info | CampAnnouncement |
| `chat` | Camp-to-camp message | Text content |
| `resource` | Request resources | ResourceRequest |
| `event` | Broadcast event | EventBroadcast |
| `emergency` | Emergency alert | Location + message |

### Camp Discovery Flow

```
1. App broadcasts DISCOVERY PING every 5 minutes
2. Other camps respond with CAMP ANNOUNCEMENT
3. Announcements include: name, location, member count
4. Discovered camps saved to local database
5. Camps not seen in 24 hours are cleaned up
```

---

## Node Types

| Node Type | Description | Capabilities |
|-----------|-------------|--------------|
| **Edge Node** | Regular phone running app | Send, receive, relay nearby |
| **Relay Node** | Phone with good battery | Extended relay duty |
| **Gateway Node** | Phone with Starlink/WiFi | Cloud sync for entire network |
| **Meshtastic Node** | Dedicated LoRa device | Long-range backbone |

### Gateway Node Detection

```swift
// Automatic detection of high-bandwidth connection
networkMonitor.pathUpdateHandler = { path in
    isGatewayNode = path.status == .satisfied &&
        (path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet))
}
```

When a device becomes a gateway node:
1. It uploads all pending sync items to CloudKit
2. It downloads messages from cloud destined for mesh
3. It relays cloud messages to local BLE/Meshtastic network
4. Other devices benefit without needing direct internet

---

## Database Schema

### Core Data Entities

```
┌─────────────────────────────────────────────────────────────────┐
│                    CORE DATA MODEL                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CachedMessage                    CachedMember                  │
│  ├─ id: UUID                      ├─ id: UUID                   │
│  ├─ senderID: String              ├─ name: String               │
│  ├─ senderName: String            ├─ role: String               │
│  ├─ recipientID: String           ├─ campID: String?            │
│  ├─ content: String               ├─ brcAddress: String?        │
│  ├─ encryptedPayload: Data?       ├─ publicKey: Data?           │
│  ├─ messageType: String           ├─ lastSeen: Date             │
│  ├─ timestamp: Date               ├─ lastLocationLat: Double    │
│  ├─ isDelivered: Bool             └─ lastLocationLon: Double    │
│  ├─ isRead: Bool                                                │
│  ├─ locationLat: Double?          CachedCamp                    │
│  ├─ locationLon: Double?          ├─ id: UUID                   │
│  └─ expiresAt: Date?              ├─ name: String               │
│                                   ├─ locationAddress: String    │
│  PendingMessage                   ├─ memberCount: Int32         │
│  ├─ id: UUID                      ├─ publicKey: Data?           │
│  ├─ recipientID: String           └─ lastBroadcast: Date        │
│  ├─ encryptedPayload: Data?                                     │
│  ├─ messageType: String           SyncQueueItem                 │
│  ├─ status: String                ├─ id: UUID                   │
│  ├─ attempts: Int32               ├─ tableName: String          │
│  ├─ createdAt: Date               ├─ recordID: String           │
│  └─ lastAttempt: Date?            ├─ operation: String          │
│                                   ├─ createdAt: Date            │
│                                   └─ isSynced: Bool             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Performance Considerations

### Battery Optimization

- BLE scanning uses low-power mode
- Meshtastic devices handle radio, phone just manages BLE
- Sync operations batched to minimize wake-ups
- Background modes limited to essential tasks

### Storage Management

- Messages expire after configurable period
- Synced items cleaned up after 7 days
- Relayed message IDs capped at 1000 (LRU eviction)
- Old camps cleaned up after 24 hours

### Network Efficiency

- Messages compressed before transmission
- Meshtastic messages limited to ~200 bytes
- Duplicate detection prevents relay loops
- Exponential backoff prevents network flooding

---

## Comparison with Similar Systems

| Feature | Robot Heart | FireChat | BitChat | Meshtastic |
|---------|-------------|----------|---------|------------|
| BLE Mesh | ✅ | ✅ | ✅ | ❌ |
| LoRa Support | ✅ | ❌ | ❌ | ✅ |
| Store-and-Forward | ✅ | ✅ | ✅ | ✅ |
| Cloud Backup | ✅ | ❌ | ❌ | ❌ |
| Multi-Camp Protocol | ✅ | ❌ | ❌ | ❌ |
| Open Source | ✅ | ❌ | ✅ | ✅ |
| End-to-End Encryption | ✅ | ❌ | ✅ | ✅ |

---

## Future Enhancements

1. **IPFS Integration** - Distributed storage for larger files
2. **Voice Messages** - Compressed audio via store-and-forward
3. **Location Beacons** - Passive location sharing for lost items
4. **Mesh Visualization** - Real-time network topology view
5. **Cross-Platform** - Android app with same protocol

---

## References

- [Meshtastic Documentation](https://meshtastic.org/docs/)
- [BitChat Whitepaper](https://github.com/nickvidal/bitchat)
- [Nodle Network](https://www.nodle.com/)
- [FireChat History](https://fromjason.xyz/p/notebook/firechat-was-a-tool-for-revolution-then-it-disappeared/)
- [Apple Core Bluetooth](https://developer.apple.com/documentation/corebluetooth)
- [Apple CloudKit](https://developer.apple.com/documentation/cloudkit)
