# Disaster-Scale Architecture

## Vision: 1 Million+ Users in Crisis

When traditional infrastructure fails—earthquake, hurricane, grid collapse, economic crisis—communities need a way to:

1. **Communicate** without internet or cellular
2. **Coordinate** without central authority
3. **Allocate resources** fairly
4. **Trust strangers** quickly
5. **Scale rapidly** from thousands to millions

This document outlines how Social Capital scales to disaster response.

---

## Scale Targets

| Scenario | Users | Geographic Area | Response Time |
|----------|-------|-----------------|---------------|
| **Camp Event** | 200 | 1 km² | Hours |
| **Burning Man** | 80,000 | 10 km² | Minutes |
| **Regional Disaster** | 500,000 | 100 km² | Minutes |
| **Major Disaster** | 5,000,000 | 1,000 km² | Seconds |
| **National Crisis** | 50,000,000 | 10,000 km² | Seconds |

---

## Hierarchical Network Architecture

### The Problem with Flat Networks

A flat mesh network doesn't scale:
- 1,000 users = 1,000,000 potential connections
- 1,000,000 users = 1,000,000,000,000 potential connections
- **Impossible to manage**

### Solution: Hierarchical Zones

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HIERARCHICAL ZONE STRUCTURE                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                           ┌─────────────┐                                   │
│                           │   REGION    │  1M+ users                        │
│                           │  COORDINATOR│  LoRa backbone                    │
│                           └──────┬──────┘                                   │
│                                  │                                          │
│              ┌───────────────────┼───────────────────┐                      │
│              │                   │                   │                      │
│       ┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐              │
│       │    ZONE     │     │    ZONE     │     │    ZONE     │  100k users  │
│       │  COMMANDER  │     │  COMMANDER  │     │  COMMANDER  │  each        │
│       └──────┬──────┘     └──────┬──────┘     └──────┬──────┘              │
│              │                   │                   │                      │
│      ┌───────┼───────┐          ...                 ...                    │
│      │       │       │                                                      │
│   ┌──┴──┐ ┌──┴──┐ ┌──┴──┐                                                  │
│   │CELL │ │CELL │ │CELL │  10k users each                                  │
│   │LEAD │ │LEAD │ │LEAD │  BLE mesh                                        │
│   └──┬──┘ └──┬──┘ └──┬──┘                                                  │
│      │       │       │                                                      │
│   ┌──┴──┐ ┌──┴──┐ ┌──┴──┐                                                  │
│   │BLOCK│ │BLOCK│ │BLOCK│  1k users each                                   │
│   │CAPT │ │CAPT │ │CAPT │  Direct contact                                  │
│   └──┬──┘ └──┬──┘ └──┬──┘                                                  │
│      │       │       │                                                      │
│   [Users] [Users] [Users]  100 users each                                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Automatic Role Assignment

When disaster strikes, **Social Capital determines who leads**:

```swift
// MARK: - Disaster Role Assignment
enum DisasterRole: Int, Comparable {
    case citizen = 0        // Everyone starts here
    case blockCaptain = 1   // Reliable+ with 5+ shifts
    case cellLead = 2       // Superstar+ with 10+ shifts
    case zoneCommander = 3  // Legendary with 20+ shifts
    case regionCoordinator = 4  // Legendary + verified training
    
    static func assign(for member: SocialCapital) -> DisasterRole {
        switch member.trustLevel {
        case .legendary where member.hasDisasterTraining:
            return .regionCoordinator
        case .legendary, .superstar where member.totalShiftsCompleted >= 20:
            return .zoneCommander
        case .superstar where member.totalShiftsCompleted >= 10:
            return .cellLead
        case .reliable where member.totalShiftsCompleted >= 5:
            return .blockCaptain
        default:
            return .citizen
        }
    }
}
```

---

## Communication Layers

### Layer 1: Direct (0-100m)
- **Technology**: Bluetooth Low Energy
- **Capacity**: ~1,000 msg/min
- **Use**: Block-level coordination
- **Latency**: <100ms

### Layer 2: Local (100m-1km)
- **Technology**: BLE Mesh relay
- **Capacity**: ~100 msg/min per hop
- **Use**: Cell-level coordination
- **Latency**: 1-5 seconds

### Layer 3: Extended (1-10km)
- **Technology**: LoRa/Meshtastic
- **Capacity**: ~10 msg/min
- **Use**: Zone-level coordination
- **Latency**: 5-30 seconds

### Layer 4: Regional (10-100km)
- **Technology**: LoRa backbone + Starlink gateways
- **Capacity**: ~1 msg/min broadcast
- **Use**: Region-level announcements
- **Latency**: 30-60 seconds

### Layer 5: Global (100km+)
- **Technology**: Satellite (Starlink/Iridium) when available
- **Capacity**: Variable
- **Use**: Cross-region coordination
- **Latency**: Minutes

```
┌─────────────────────────────────────────────────────────────────┐
│                    COMMUNICATION LAYERS                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  LAYER 5: GLOBAL ─────────────────────────────────── 100km+    │
│  │ Satellite (when available)                                  │
│  │                                                              │
│  LAYER 4: REGIONAL ───────────────────────────────── 10-100km  │
│  │ LoRa backbone + Starlink gateways                           │
│  │                                                              │
│  LAYER 3: EXTENDED ───────────────────────────────── 1-10km    │
│  │ LoRa/Meshtastic                                             │
│  │                                                              │
│  LAYER 2: LOCAL ──────────────────────────────────── 100m-1km  │
│  │ BLE Mesh relay                                              │
│  │                                                              │
│  LAYER 1: DIRECT ─────────────────────────────────── 0-100m    │
│    Bluetooth Low Energy                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Resource Allocation Protocol

### The Problem

In a disaster, resources are scarce:
- Water
- Food
- Medical supplies
- Shelter
- Transportation
- Power/fuel

**How do you allocate fairly without central authority?**

### Solution: Need + Trust + Contribution

```swift
// MARK: - Resource Allocation
struct ResourceAllocation {
    
    /// Calculate priority score for resource allocation
    /// Higher score = higher priority
    static func priorityScore(
        for member: SocialCapital,
        need: NeedLevel,
        resourceType: ResourceType
    ) -> Double {
        var score = 0.0
        
        // Base: Need level (most important)
        switch need {
        case .critical: score += 100  // Life-threatening
        case .urgent: score += 70     // Serious but stable
        case .moderate: score += 40   // Can wait hours
        case .low: score += 10        // Can wait days
        }
        
        // Modifier: Vulnerability
        if member.isVulnerable {
            score += 30  // Children, elderly, disabled, pregnant
        }
        
        // Modifier: Trust level (tie-breaker, not primary)
        switch member.trustLevel {
        case .legendary: score += 5
        case .superstar: score += 4
        case .reliable: score += 3
        case .contributing: score += 2
        case .improving: score += 1
        case .new: score += 0
        }
        
        // Modifier: Recent contribution (rewarding active helpers)
        if member.contributedInLast24Hours {
            score += 10
        }
        
        // Modifier: Time waiting (prevents starvation)
        let hoursWaiting = member.hoursInQueue(for: resourceType)
        score += min(20, hoursWaiting * 2)
        
        return score
    }
    
    enum NeedLevel: Int {
        case critical = 4  // Will die without
        case urgent = 3    // Serious harm without
        case moderate = 2  // Significant hardship
        case low = 1       // Inconvenience
    }
    
    enum ResourceType {
        case water
        case food
        case medical
        case shelter
        case power
        case transportation
        case communication
    }
}
```

### Allocation Process

```
┌─────────────────────────────────────────────────────────────────┐
│                    RESOURCE ALLOCATION FLOW                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. NEED REPORTED                                              │
│     └── User reports need via app                              │
│     └── Need level assessed (critical/urgent/moderate/low)     │
│                                                                 │
│  2. VERIFICATION                                               │
│     └── Block Captain verifies need (if possible)              │
│     └── Or: Multiple peer witnesses                            │
│     └── Or: Self-report with photo evidence                    │
│                                                                 │
│  3. QUEUE ENTRY                                                │
│     └── Priority score calculated                              │
│     └── Added to resource queue                                │
│     └── Position visible to user                               │
│                                                                 │
│  4. RESOURCE AVAILABLE                                         │
│     └── Highest priority served first                          │
│     └── Allocation logged on-device                            │
│     └── Receipt confirmed by both parties                      │
│                                                                 │
│  5. POST-ALLOCATION                                            │
│     └── Social Capital updated (if contributed)                │
│     └── Need status updated                                    │
│     └── Analytics for future planning                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Emergency Roles & Capabilities

### Disaster-Specific Trust Levels

```swift
// MARK: - Disaster Capabilities
struct DisasterCapabilities {
    
    /// What each trust level can do in a disaster
    static func capabilities(for level: SocialCapital.TrustLevel) -> [Capability] {
        switch level {
        case .new:
            return [
                .reportNeed,
                .receiveResources,
                .viewLocalInfo
            ]
            
        case .improving:
            return [
                .reportNeed,
                .receiveResources,
                .viewLocalInfo,
                .relayMessages
            ]
            
        case .contributing:
            return [
                .reportNeed,
                .receiveResources,
                .viewLocalInfo,
                .relayMessages,
                .verifyNeeds,
                .distributeResources
            ]
            
        case .reliable:
            return [
                .reportNeed,
                .receiveResources,
                .viewLocalInfo,
                .relayMessages,
                .verifyNeeds,
                .distributeResources,
                .coordinateBlock,
                .requestResources
            ]
            
        case .superstar:
            return [
                .all,
                .coordinateCell,
                .allocateResources,
                .dispatchTeams
            ]
            
        case .legendary:
            return [
                .all,
                .coordinateZone,
                .declareEmergency,
                .overrideAllocation,
                .crossZoneCoordination
            ]
        }
    }
    
    enum Capability {
        case reportNeed
        case receiveResources
        case viewLocalInfo
        case relayMessages
        case verifyNeeds
        case distributeResources
        case coordinateBlock
        case requestResources
        case coordinateCell
        case allocateResources
        case dispatchTeams
        case coordinateZone
        case declareEmergency
        case overrideAllocation
        case crossZoneCoordination
        case all
    }
}
```

---

## Rapid Onboarding Protocol

### The Challenge

In a disaster, you need to onboard **thousands of new users per hour** who have:
- No existing Social Capital
- No prior relationship with the network
- Urgent needs

### Solution: Vouching + Provisional Trust

```swift
// MARK: - Rapid Onboarding
struct RapidOnboarding {
    
    /// Onboard a new user during disaster
    static func onboard(
        newUser: User,
        vouchedBy: SocialCapital?,
        context: DisasterContext
    ) -> SocialCapital {
        var capital = SocialCapital(
            memberID: newUser.id,
            displayName: newUser.name
        )
        
        // Provisional trust based on voucher
        if let voucher = vouchedBy {
            switch voucher.trustLevel {
            case .legendary, .superstar:
                capital.provisionalLevel = .contributing
                capital.provisionalExpiry = Date().addingTimeInterval(72 * 3600)
            case .reliable:
                capital.provisionalLevel = .improving
                capital.provisionalExpiry = Date().addingTimeInterval(48 * 3600)
            default:
                capital.provisionalLevel = .new
            }
        }
        
        // Emergency context boost
        if context.isActiveEmergency {
            // Everyone gets basic capabilities during active emergency
            capital.emergencyCapabilities = [
                .reportNeed,
                .receiveResources,
                .relayMessages
            ]
        }
        
        return capital
    }
    
    /// Verify identity post-disaster
    static func verifyPostDisaster(
        capital: inout SocialCapital,
        verifiedBy: [SocialCapital]
    ) {
        // Require 3 trusted members to verify
        let trustedVerifiers = verifiedBy.filter { 
            $0.trustLevel >= .reliable 
        }
        
        if trustedVerifiers.count >= 3 {
            capital.isVerified = true
            capital.provisionalLevel = nil
            capital.provisionalExpiry = nil
        }
    }
}
```

### Onboarding Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    RAPID ONBOARDING FLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: DOWNLOAD & INSTALL (30 seconds)                       │
│  └── App available via:                                        │
│      • AirDrop from nearby device                              │
│      • QR code to App Store (if internet)                      │
│      • Pre-loaded on emergency devices                         │
│                                                                 │
│  STEP 2: IDENTITY CREATION (60 seconds)                        │
│  └── Name (playa name or real)                                 │
│  └── Photo (optional but helps verification)                   │
│  └── Location (auto-detected or manual)                        │
│  └── Cryptographic key generated                               │
│                                                                 │
│  STEP 3: VOUCHING (optional, 30 seconds)                       │
│  └── Scan QR of trusted member                                 │
│  └── Or: Enter voucher's ID                                    │
│  └── Provisional trust granted                                 │
│                                                                 │
│  STEP 4: MESH CONNECTION (automatic)                           │
│  └── BLE scanning starts                                       │
│  └── Connects to nearby peers                                  │
│  └── Receives local emergency info                             │
│                                                                 │
│  STEP 5: READY (< 3 minutes total)                             │
│  └── Can report needs                                          │
│  └── Can receive resources                                     │
│  └── Can relay messages                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Structures for Scale

### Efficient Message Format

```swift
// MARK: - Compact Disaster Message
/// Optimized for low-bandwidth transmission
struct DisasterMessage: Codable {
    // Header (16 bytes)
    let id: UInt64           // 8 bytes - unique ID
    let timestamp: UInt32    // 4 bytes - seconds since epoch
    let type: UInt8          // 1 byte - message type
    let priority: UInt8      // 1 byte - 0-255
    let ttl: UInt8           // 1 byte - hops remaining
    let flags: UInt8         // 1 byte - bitflags
    
    // Routing (16 bytes)
    let senderID: UInt64     // 8 bytes - truncated hash
    let targetZone: UInt32   // 4 bytes - geographic zone
    let targetCell: UInt16   // 2 bytes - cell within zone
    let targetBlock: UInt16  // 2 bytes - block within cell
    
    // Payload (variable, max 200 bytes)
    let payload: Data
    
    // Signature (64 bytes)
    let signature: Data      // Ed25519 signature
    
    // Total: 96 bytes + payload
    // Max: 296 bytes (fits in single LoRa packet)
    
    enum MessageType: UInt8 {
        case emergency = 0      // SOS, life-threatening
        case resource = 1       // Resource request/offer
        case status = 2         // Status update
        case coordination = 3   // Leadership coordination
        case broadcast = 4      // Zone-wide announcement
        case ack = 5            // Acknowledgment
        case heartbeat = 6      // I'm alive
    }
}
```

### Zone Registry

```swift
// MARK: - Zone Registry
/// Hierarchical geographic organization
struct ZoneRegistry {
    // Global zone map (loaded from seed data or discovered)
    var regions: [RegionID: Region] = [:]
    
    struct Region {
        let id: RegionID
        var name: String
        var zones: [ZoneID: Zone]
        var coordinator: SocialCapital?
        var population: Int
        var status: DisasterStatus
    }
    
    struct Zone {
        let id: ZoneID
        var name: String
        var cells: [CellID: Cell]
        var commander: SocialCapital?
        var population: Int
        var resources: [ResourceType: Int]
        var needs: [ResourceType: Int]
    }
    
    struct Cell {
        let id: CellID
        var blocks: [BlockID: Block]
        var lead: SocialCapital?
        var population: Int
        var lastHeartbeat: Date
    }
    
    struct Block {
        let id: BlockID
        var captain: SocialCapital?
        var members: [String]  // Member IDs
        var location: Coordinate
        var status: BlockStatus
    }
    
    enum DisasterStatus {
        case normal
        case alert
        case emergency
        case critical
        case recovery
    }
}
```

---

## Offline-First Data Sync

### Conflict Resolution

When devices reconnect after being offline:

```swift
// MARK: - Conflict Resolution
struct ConflictResolution {
    
    /// Resolve conflicts when syncing after offline period
    static func resolve(
        local: SocialCapital,
        remote: SocialCapital
    ) -> SocialCapital {
        var merged = local
        
        // Shifts: Take maximum (can't un-complete a shift)
        merged.totalShiftsCompleted = max(
            local.totalShiftsCompleted,
            remote.totalShiftsCompleted
        )
        
        // No-shows: Take maximum (can't un-no-show)
        merged.totalNoShows = max(
            local.totalNoShows,
            remote.totalNoShows
        )
        
        // Events: Union of both histories
        let localEvents = Set(local.eventHistory.map { $0.id })
        let remoteEvents = Set(remote.eventHistory.map { $0.id })
        let allEventIDs = localEvents.union(remoteEvents)
        
        merged.eventHistory = allEventIDs.compactMap { id in
            local.eventHistory.first { $0.id == id } ??
            remote.eventHistory.first { $0.id == id }
        }
        
        // Last active: Take most recent
        if let localDate = local.lastActiveDate,
           let remoteDate = remote.lastActiveDate {
            merged.lastActiveDate = max(localDate, remoteDate)
        }
        
        return merged
    }
    
    /// Resolve resource allocation conflicts
    static func resolveAllocation(
        local: ResourceAllocation,
        remote: ResourceAllocation
    ) -> ResourceAllocation {
        // If both allocated same resource, honor earlier timestamp
        if local.timestamp < remote.timestamp {
            return local
        }
        return remote
    }
}
```

---

## Emergency Protocols

### Protocol 1: Mass Casualty Event

```
┌─────────────────────────────────────────────────────────────────┐
│                    MASS CASUALTY PROTOCOL                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TRIGGER: Multiple SOS messages in same zone                   │
│                                                                 │
│  AUTOMATIC ACTIONS:                                            │
│  1. Zone status → CRITICAL                                     │
│  2. All Legendary/Superstar members notified                   │
│  3. Resource requests prioritized to zone                      │
│  4. Adjacent zones alerted                                     │
│  5. Message rate limits relaxed for zone                       │
│                                                                 │
│  COORDINATION:                                                 │
│  • Zone Commander takes lead                                   │
│  • Cell Leads report status every 15 min                       │
│  • Block Captains do headcount                                 │
│  • Medical-trained members identified                          │
│                                                                 │
│  RESOURCE FLOW:                                                │
│  • Medical supplies → Critical zone                            │
│  • Water/food → Adjacent staging areas                         │
│  • Transportation → Evacuation routes                          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Protocol 2: Communication Blackout

```
┌─────────────────────────────────────────────────────────────────┐
│                    BLACKOUT PROTOCOL                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TRIGGER: No external communication for 1 hour                 │
│                                                                 │
│  AUTOMATIC ACTIONS:                                            │
│  1. Switch to full mesh mode                                   │
│  2. Extend LoRa transmission power                             │
│  3. Activate store-and-forward                                 │
│  4. Begin hourly heartbeat broadcasts                          │
│                                                                 │
│  COORDINATION:                                                 │
│  • Each block does roll call                                   │
│  • Status aggregated up hierarchy                              │
│  • Runners designated for physical message relay               │
│  • Solar/battery charging prioritized                          │
│                                                                 │
│  INFORMATION FLOW:                                             │
│  • Critical only via LoRa (bandwidth limited)                  │
│  • Routine via BLE mesh                                        │
│  • Bulk data via physical device transfer                      │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Protocol 3: Resource Scarcity

```
┌─────────────────────────────────────────────────────────────────┐
│                    SCARCITY PROTOCOL                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  TRIGGER: Resource level < 20% of need                         │
│                                                                 │
│  AUTOMATIC ACTIONS:                                            │
│  1. Rationing mode activated                                   │
│  2. Allocation algorithm switches to strict priority           │
│  3. Hoarding detection enabled                                 │
│  4. Cross-zone resource requests initiated                     │
│                                                                 │
│  ALLOCATION RULES:                                             │
│  • Critical needs only                                         │
│  • Vulnerable populations first                                │
│  • Maximum per person per day enforced                         │
│  • Receipts required for all distributions                     │
│                                                                 │
│  ANTI-HOARDING:                                                │
│  • Anomaly detection for multiple requests                     │
│  • Peer verification required                                  │
│  • Social Capital penalty for confirmed hoarding               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Hardware Recommendations

### Minimum Device Requirements

| Component | Requirement | Purpose |
|-----------|-------------|---------|
| **Phone** | iOS 15+ or Android 10+ | App platform |
| **BLE** | Bluetooth 5.0+ | Local mesh |
| **Storage** | 1 GB free | Offline data |
| **Battery** | 4+ hours | Sustained operation |

### Recommended Additions

| Device | Cost | Range | Purpose |
|--------|------|-------|---------|
| **Meshtastic Radio** | $35 | 10 km | Extended mesh |
| **Solar Charger** | $25 | N/A | Power independence |
| **Portable Battery** | $30 | N/A | Extended operation |
| **Faraday Bag** | $15 | N/A | EMP protection |

### Infrastructure Nodes

| Node Type | Cost | Coverage | Deployment |
|-----------|------|----------|------------|
| **Block Node** | $100 | 500m | Every 10 blocks |
| **Cell Node** | $500 | 2 km | Every cell |
| **Zone Node** | $2,000 | 10 km | Every zone |
| **Region Node** | $10,000 | 100 km | Every region |

---

## Deployment Strategy

### Phase 1: Seed Network (Now)
- Robot Heart camp as proof of concept
- 200 trusted members with Social Capital
- Test all protocols at Burning Man

### Phase 2: Regional Burns (Year 1)
- Expand to 10 regional burns
- 2,000 trusted members
- Cross-event trust verification

### Phase 3: Year-Round Network (Year 2)
- Off-season events and meetups
- 10,000 trusted members
- Continuous network operation

### Phase 4: Disaster Readiness (Year 3)
- Partner with emergency services
- Pre-position infrastructure nodes
- 100,000 trained members
- Conduct disaster drills

### Phase 5: Scale Deployment (Year 5)
- 1,000,000+ members
- Coverage in major metro areas
- Integration with official emergency systems
- Self-sustaining organization

---

## Success Metrics

### Network Health
- **Coverage**: % of area with mesh connectivity
- **Latency**: Time for message to traverse network
- **Reliability**: % of messages successfully delivered
- **Uptime**: % of time network is operational

### Community Health
- **Trust Distribution**: % at each trust level
- **Participation Rate**: % active in last 30 days
- **Verification Rate**: % of members verified
- **Response Time**: Average time to respond to need

### Disaster Readiness
- **Drill Success Rate**: % of drills completed successfully
- **Resource Coverage**: Days of supplies pre-positioned
- **Leadership Depth**: # of qualified leaders per zone
- **Onboarding Speed**: Time to onboard new user

---

## Conclusion

This architecture enables Social Capital to scale from a camp of 200 to a disaster response network of millions. The key principles:

1. **Hierarchical organization** prevents network congestion
2. **Trust-based leadership** ensures qualified coordination
3. **Multi-layer communication** provides resilience
4. **Fair resource allocation** prevents conflict
5. **Rapid onboarding** enables emergency growth
6. **Offline-first design** works without infrastructure

**When traditional systems fail, this network stands ready.**

---

*Robot Heart Foundation • Disaster Resilience Initiative • 2026*
