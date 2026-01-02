# Robot Heart Network Architecture - Multi-Layer Strategy

**Date**: 2026-01-02  
**Status**: Design Complete, Implementation In Progress

---

## Overview

The Robot Heart network implements a **4-layer communication strategy** that prioritizes offline-first operation while opportunistically using internet connectivity when available. This design ensures the app works in complete disaster scenarios (no internet, no cell service) while automatically leveraging faster, higher-bandwidth connections when they exist.

### Design Principles

1. **Offline-First**: App must work with zero internet connectivity
2. **Opportunistic Upgrade**: Automatically use internet when available
3. **No Single Point of Failure**: Mesh continues working if cloud is down
4. **Gateway Nodes**: Devices with internet act as bridges
5. **Store-and-Forward**: Messages persist until delivered, even across network transitions
6. **Bandwidth Optimization**: Use appropriate layer for each message type

---

## Network Layers (Priority Order)

### Layer 1: Cloud Sync (Highest Bandwidth, Lowest Latency)

**Technology**: HTTPS REST API + WebSocket  
**Range**: Global (requires internet)  
**Bandwidth**: ~10+ Mbps  
**Latency**: ~50-200ms  
**Power**: Medium (WiFi) to High (Cellular)

**Use Cases:**
- Real-time messaging when internet available
- Large file transfers (photos, camp layouts)
- Cross-camp coordination (Robot Heart ↔ other camps)
- Historical data sync
- Analytics and monitoring

**Infrastructure:**
- **Storage**: Digital Ocean S3 buckets
- **API**: Lightweight REST API (can be serverless)
- **Database**: Key-value store for message queue (Redis/DynamoDB)
- **WebSocket**: For real-time push notifications

**When Active:**
- Device connected to WiFi (Starlink, camp WiFi)
- Device has cellular data service
- Device is designated as "gateway node"

---

### Layer 2: Meshtastic LoRa (Long-Range Mesh)

**Technology**: LoRa mesh via Meshtastic protocol  
**Range**: 5-15 km typical, up to 331 km record  
**Bandwidth**: ~200 bytes per message  
**Latency**: ~1-5 seconds  
**Power**: Very Low

**Use Cases:**
- Cross-playa communication (camp to camp)
- Emergency alerts and SOS
- Location sharing
- Text messages
- Announcements

**Hardware:**
- SenseCAP T1000-E Card Tracker (primary)
- RAK WisMesh devices (alternative)

**When Active:**
- Always (primary offline layer)
- Fallback when internet unavailable

---

### Layer 3: BLE Mesh (Short-Range Peer-to-Peer)

**Technology**: Bluetooth Low Energy mesh  
**Range**: 10-100 meters  
**Bandwidth**: ~1 Mbps  
**Latency**: <100ms  
**Power**: Very Low

**Use Cases:**
- Immediate presence detection ("who's nearby?")
- In-camp communication
- High-bandwidth local transfers (when in range)
- Peer discovery

**When Active:**
- Always (for presence detection)
- Opportunistically for data transfer when peers in range

---

### Layer 4: Local Storage (Offline Cache)

**Technology**: Core Data + SQLite  
**Range**: Device only  
**Bandwidth**: N/A  
**Latency**: <10ms  
**Power**: Minimal

**Use Cases:**
- Message queue when offline
- Local data persistence
- Historical messages
- User profiles and settings

**When Active:**
- Always (foundation for offline-first)

---

## Gateway Node Architecture

### What is a Gateway Node?

A **gateway node** is any device that has internet connectivity (WiFi or cellular) and acts as a bridge between the offline mesh network and the cloud. Multiple devices can be gateway nodes simultaneously.

### Gateway Node Responsibilities

1. **Relay Mesh → Cloud**: Forward messages from mesh network to cloud API
2. **Relay Cloud → Mesh**: Push cloud messages to mesh network
3. **Sync State**: Upload local state to cloud for other gateways
4. **Conflict Resolution**: Handle message deduplication and ordering

### Gateway Node Detection

Devices automatically detect when they become gateway nodes:

```swift
// Pseudo-code
if hasInternetConnectivity() {
    becomeGatewayNode()
    startRelayingMessages()
} else {
    resignGatewayNode()
    useOfflineMeshOnly()
}
```

### Multiple Gateway Nodes

When multiple devices have internet:
- All act as gateways simultaneously
- Cloud deduplicates messages by message ID
- Improves reliability (redundancy)
- No coordination needed between gateways

---

## Message Routing Logic

The `NetworkOrchestrator` uses this decision tree:

```
┌─────────────────────────────────────┐
│ New Message to Send                 │
└──────────────┬──────────────────────┘
               │
               ▼
       ┌───────────────┐
       │ Has Internet? │
       └───────┬───────┘
               │
        ┌──────┴──────┐
        │             │
       YES           NO
        │             │
        ▼             ▼
   ┌─────────┐   ┌──────────┐
   │ Layer 1 │   │ Layer 2  │
   │ Cloud   │   │ LoRa     │
   │ (Fast)  │   │ (Mesh)   │
   └─────────┘   └──────────┘
        │             │
        ▼             ▼
   ┌─────────────────────┐
   │ Store in Local DB   │
   │ (Layer 4)           │
   └─────────────────────┘
        │
        ▼
   ┌─────────────────────┐
   │ Also Send via LoRa  │
   │ (Redundancy)        │
   └─────────────────────┘
```

### Routing Rules

| Message Type | Priority 1 | Priority 2 | Priority 3 |
|:-------------|:-----------|:-----------|:-----------|
| **Text Message** | Cloud (if online) | LoRa | BLE (if in range) |
| **Emergency SOS** | Cloud + LoRa (both) | BLE | Local only |
| **Location Update** | Cloud (if online) | LoRa | Local only |
| **Presence** | BLE | Local only | - |
| **Large File** | Cloud (if online) | BLE (if in range) | Queue for later |
| **Announcement** | Cloud + LoRa (both) | BLE | Local only |

### Key Insight: Redundancy for Critical Messages

For **emergency** and **announcement** messages, send via **both** cloud and LoRa simultaneously to maximize delivery probability.

---

## Cloud Infrastructure Design

### Digital Ocean S3 Bucket Structure

```
robot-heart-mesh/
├── messages/
│   ├── {message_id}.json          # Individual messages
│   └── index/
│       └── {camp_id}.json         # Message index per camp
├── locations/
│   └── {user_id}/
│       └── latest.json            # Latest location per user
├── camps/
│   └── {camp_id}/
│       ├── layout.json            # Camp layout data
│       └── members.json           # Member roster
├── sync/
│   └── {device_id}/
│       └── queue.json             # Pending messages per device
└── assets/
    └── {asset_id}.{ext}           # Photos, files, etc.
```

### API Endpoints (Lightweight REST)

Can be implemented as serverless functions (DigitalOcean Functions, AWS Lambda, Cloudflare Workers):

```
POST   /api/v1/messages              # Send message to cloud
GET    /api/v1/messages?camp={id}    # Get messages for camp
POST   /api/v1/locations             # Update location
GET    /api/v1/locations?camp={id}   # Get all camp locations
POST   /api/v1/sync                  # Sync device state
GET    /api/v1/sync?device={id}      # Get pending messages
```

### Authentication

Use **device-based tokens** (not user accounts):
- Each device generates a unique ID on first launch
- Device ID + camp ID = authentication token
- No passwords, no login (true peer-to-peer)
- Optional: Sign messages with device keys for verification

### Message Format (JSON)

```json
{
  "id": "msg_abc123",
  "type": "text",
  "from": "device_xyz789",
  "from_name": "Alice",
  "camp_id": "robot-heart",
  "content": "Meet at the bus at sunset!",
  "location": {
    "lat": 40.7864,
    "lon": -119.2065
  },
  "timestamp": "2026-08-25T18:30:00Z",
  "ttl": 604800,
  "signature": "..."
}
```

---

## Store-and-Forward Strategy

### Message Queue States

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ PENDING  │ --> │ SENDING  │ --> │   SENT   │ --> │ DELIVERED│
└──────────┘     └──────────┘     └──────────┘     └──────────┘
     │                                                     │
     └─────────────────────────────────────────────────────┘
                    (Retry on failure)
```

### Retry Logic

- **Immediate Retry**: If send fails, retry after 5 seconds
- **Exponential Backoff**: 5s, 10s, 30s, 1m, 5m, 15m, 1h
- **Max Retries**: Keep trying for 7 days (TTL)
- **Network Transition**: Retry immediately when network changes (offline → online)

### Deduplication

Messages are deduplicated by `message_id`:
- Client generates UUID for each message
- Cloud and mesh nodes track seen message IDs
- Duplicate messages are silently dropped
- Seen IDs cached for 7 days

---

## Implementation Priority

### Phase 2A: Cloud Sync Service ✅ (This Session)

1. Create `CloudSyncService` (decomposed from `CloudSyncManager`)
2. Implement Digital Ocean S3 integration
3. Add internet connectivity detection
4. Implement gateway node auto-promotion

### Phase 2B: Service Decomposition ✅ (This Session)

1. Break down `MeshtasticManager` into 5 focused services
2. Break down `ShiftManager` into 3 focused services
3. Update `AppEnvironment` to use new services

### Phase 2C: Network Orchestrator Update ✅ (This Session)

1. Add Layer 1 (Cloud) to routing logic
2. Implement redundancy for critical messages
3. Add network transition handling
4. Implement message queue retry logic

---

## Testing Strategy

### Scenarios to Test

1. **Pure Offline**: No internet, only LoRa + BLE
2. **Gateway Node**: One device with WiFi, others offline
3. **Multiple Gateways**: Multiple devices with internet
4. **Network Transition**: Device goes online → offline → online
5. **Message Delivery**: Verify messages delivered via all layers
6. **Deduplication**: Verify no duplicate messages received
7. **Disaster Scenario**: Complete internet outage, mesh continues

### Metrics to Monitor

- Message delivery rate per layer
- Average latency per layer
- Battery consumption per layer
- Gateway node uptime
- Cloud sync success rate

---

## Security Considerations

### Offline-First Security

- **No Authentication Required**: App works without login
- **Device-Based Identity**: Each device has unique ID
- **Optional Signatures**: Messages can be signed for verification
- **End-to-End Encryption**: Planned for private messages

### Cloud Security

- **Device Tokens**: Prevent unauthorized access
- **Rate Limiting**: Prevent abuse
- **Message TTL**: Auto-delete old messages
- **Camp Isolation**: Camps can't see each other's messages

---

## Cost Estimation (Digital Ocean)

### S3 Storage
- **Estimate**: 10,000 messages/day × 1KB = 10MB/day = 300MB/month
- **Cost**: $0.02/GB/month = **$0.006/month** (negligible)

### Bandwidth
- **Estimate**: 10,000 messages/day × 2KB (in+out) = 20MB/day = 600MB/month
- **Cost**: $0.01/GB = **$0.006/month** (negligible)

### API Calls (if using Functions)
- **Estimate**: 10,000 messages/day × 30 days = 300,000 calls/month
- **Cost**: Free tier covers 90,000 calls, then $0.0000025/call = **$0.53/month**

**Total Estimated Cost**: **<$1/month** for 10,000 messages/day

---

## Conclusion

This 4-layer architecture provides:

✅ **Disaster-Ready**: Works with zero internet  
✅ **Opportunistic**: Uses internet when available  
✅ **Resilient**: No single point of failure  
✅ **Scalable**: Handles 10,000+ messages/day  
✅ **Cost-Effective**: <$1/month for cloud infrastructure  
✅ **Fast**: Sub-second delivery when online  
✅ **Reliable**: Store-and-forward ensures delivery  

The system gracefully degrades from Cloud → LoRa → BLE → Local, ensuring communication is always possible.

---

*Next: Implement CloudSyncService and update NetworkOrchestrator*
