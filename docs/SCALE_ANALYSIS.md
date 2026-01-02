# Robot Heart Scale & Security Analysis

## Executive Summary

This document analyzes how the Robot Heart app would perform at scale in a scenario where traditional infrastructure (internet, cellular, government services) becomes unreliable. We examine bottlenecks, attack vectors, and propose hardening measures.

---

## Current Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ROBOT HEART ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────┐    BLE Mesh     ┌─────────┐    LoRa Mesh    ┌─────────┐      │
│  │ Phone A │◄──────────────►│ Phone B │◄───────────────►│ Radio C │      │
│  └────┬────┘                 └────┬────┘                 └────┬────┘      │
│       │                           │                           │            │
│       ▼                           ▼                           ▼            │
│  ┌─────────┐                 ┌─────────┐                 ┌─────────┐      │
│  │ SQLite  │                 │ SQLite  │                 │ SQLite  │      │
│  │ (Local) │                 │ (Local) │                 │ (Local) │      │
│  └────┬────┘                 └────┬────┘                 └────┬────┘      │
│       │                           │                           │            │
│       └───────────────────────────┼───────────────────────────┘            │
│                                   │                                        │
│                          Gateway Node (Starlink)                           │
│                                   │                                        │
│                                   ▼                                        │
│                            ┌───────────┐                                   │
│                            │ CloudKit  │                                   │
│                            │  (Apple)  │                                   │
│                            └───────────┘                                   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Scale Analysis

### Scenario Parameters

| Parameter | Small Event | Burning Man | Disaster Response | Max Theoretical |
|-----------|-------------|-------------|-------------------|-----------------|
| **Users** | 200 | 80,000 | 1,000,000 | 10,000,000 |
| **Messages/day** | 2,000 | 800,000 | 10,000,000 | 100,000,000 |
| **Concurrent connections** | 20 | 500 | 5,000 | 50,000 |
| **Geographic spread** | 1 km² | 10 km² | 1,000 km² | Global |

### Current Bottlenecks

#### 1. BLE Mesh Limitations

| Constraint | Current Limit | Impact |
|------------|---------------|--------|
| **BLE Range** | ~100m line-of-sight | Requires dense device distribution |
| **Connected Peers** | ~7 per device (iOS limit) | Limits direct connections |
| **Message Size** | ~512 bytes (MTU) | Requires fragmentation for larger messages |
| **Throughput** | ~1 Mbps shared | Congestion with many devices |
| **Battery Drain** | ~5-10% per hour active | Limits continuous operation |

**Bottleneck Analysis:**
```
At 1,000 users in 1 km²:
- Average density: 1 user per 1,000 m²
- Average BLE hops needed: 3-5
- Message latency: 500ms - 2s per hop
- Total latency: 1.5s - 10s for delivery
- Collision probability: ~15% at peak load
```

#### 2. LoRa/Meshtastic Limitations

| Constraint | Current Limit | Impact |
|------------|---------------|--------|
| **Range** | 1-10 km (terrain dependent) | Better for sparse areas |
| **Data Rate** | ~300 bps | Very slow for text |
| **Message Size** | ~200 bytes | Severe content limits |
| **Channel Capacity** | ~100 msg/hour/channel | Easy to saturate |
| **Duty Cycle** | 1-10% (regulatory) | Can't transmit continuously |

**Bottleneck Analysis:**
```
At 10,000 users on single LoRa channel:
- Max messages/hour: 100 (regulatory limit)
- Per-user capacity: 0.01 msg/hour
- UNUSABLE without channel splitting
```

#### 3. Local Storage (SQLite/Core Data)

| Constraint | Current Limit | Impact |
|------------|---------------|--------|
| **Database Size** | ~1 GB practical | Fills up over time |
| **Query Performance** | Degrades >100k rows | Slow UI at scale |
| **Write Throughput** | ~1000 writes/sec | Adequate |
| **Memory Usage** | Grows with cache | OOM risk |

#### 4. Social Capital Calculation

| Operation | Current Complexity | At Scale |
|-----------|-------------------|----------|
| **Trust Level Calc** | O(1) | Fine |
| **Network Query** | O(n) members | Slow at 10k+ |
| **Leaderboard Sort** | O(n log n) | Slow at 10k+ |
| **Event History** | O(events) | Grows unbounded |

---

## Message Pruning Strategy

### Current State: NO PRUNING
Messages accumulate indefinitely → **Critical vulnerability**

### Proposed Pruning Policies

```swift
// MARK: - Message Retention Policy
struct MessageRetentionPolicy {
    
    // Tier 1: Hot Storage (device memory)
    static let hotStorageLimit = 1000  // messages
    static let hotStorageAge = TimeInterval(7 * 24 * 3600)  // 7 days
    
    // Tier 2: Warm Storage (SQLite)
    static let warmStorageLimit = 10000  // messages
    static let warmStorageAge = TimeInterval(30 * 24 * 3600)  // 30 days
    
    // Tier 3: Cold Storage (archived, compressed)
    static let coldStorageLimit = 100000  // messages
    static let coldStorageAge = TimeInterval(365 * 24 * 3600)  // 1 year
    
    // Pruning Rules
    enum PruneRule {
        case byAge(maxAge: TimeInterval)
        case byCount(maxCount: Int)
        case byType(keepTypes: [MessageType])
        case byDeliveryStatus(pruneUndelivered: Bool)
        case byImportance(minImportance: Int)
    }
    
    // Message Importance Scoring
    static func importance(of message: Message) -> Int {
        var score = 0
        
        // Base scores by type
        switch message.type {
        case .emergency: score += 100  // Never auto-prune
        case .announcement: score += 50
        case .shiftUpdate: score += 30
        case .text: score += 10
        case .location: score += 5
        }
        
        // Boost for unread
        if !message.isRead { score += 20 }
        
        // Boost for direct messages (vs broadcast)
        if message.recipientID != "broadcast" { score += 15 }
        
        // Decay by age (lose 1 point per day)
        let daysOld = message.timestamp.timeIntervalSinceNow / -86400
        score -= Int(daysOld)
        
        return max(0, score)
    }
}
```

### Pruning Implementation

```swift
// MARK: - Pruning Manager
class PruningManager {
    
    /// Run pruning on a schedule (e.g., daily at 3 AM)
    func runScheduledPrune() {
        let policy = MessageRetentionPolicy.self
        
        // Phase 1: Prune by age
        pruneMessagesOlderThan(policy.warmStorageAge)
        
        // Phase 2: Prune by count (keep most important)
        if messageCount > policy.warmStorageLimit {
            pruneLowestImportance(
                targetCount: policy.warmStorageLimit,
                protectTypes: [.emergency]
            )
        }
        
        // Phase 3: Archive to cold storage
        archiveOldMessages(olderThan: policy.hotStorageAge)
        
        // Phase 4: Vacuum database
        vacuumDatabase()
    }
    
    /// Prune relay cache (prevent memory exhaustion)
    func pruneRelayCache() {
        // Keep only last 1000 message IDs for duplicate detection
        if relayedMessageIDs.count > 1000 {
            // Remove oldest 500 (FIFO)
            relayedMessageIDs = Set(relayedMessageIDs.suffix(500))
        }
    }
    
    /// Emergency prune when storage is critical
    func emergencyPrune() {
        // Delete all delivered messages older than 24 hours
        pruneMessagesOlderThan(86400, onlyDelivered: true)
        
        // Delete all location messages older than 1 hour
        pruneByType(.location, olderThan: 3600)
        
        // Compact database
        vacuumDatabase()
    }
}
```

---

## Gaming & Abuse Vectors

### 1. Social Capital Gaming

| Attack | Description | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Shift Fraud** | Claim shifts, don't show up, mark complete | Inflated reputation | Require peer verification |
| **Sybil Attack** | Create fake accounts to vouch for self | Fake trust network | Device binding, invite-only |
| **Collusion** | Friends mark each other's shifts complete | Mutual inflation | Random spot checks |
| **Point Farming** | Claim easy shifts, avoid hard ones | Gaming leaderboard | Weighted difficulty scoring |

**Mitigation: Proof of Participation**

```swift
// MARK: - Shift Verification
struct ShiftVerification {
    
    enum VerificationMethod {
        case leadConfirmation      // Lead marks complete
        case peerWitness(count: Int)  // N peers confirm presence
        case locationProof         // GPS at shift location
        case photoProof            // Timestamped photo
        case qrCheckIn             // Scan QR at location
    }
    
    // Require multiple verification methods for high-value shifts
    static func requiredVerifications(for shift: Shift) -> [VerificationMethod] {
        switch shift.pointValue {
        case 0..<10:
            return [.leadConfirmation]
        case 10..<25:
            return [.leadConfirmation, .locationProof]
        case 25...:
            return [.leadConfirmation, .peerWitness(count: 2), .locationProof]
        default:
            return [.leadConfirmation]
        }
    }
    
    // Anomaly detection
    static func detectAnomalies(for member: Member) -> [Anomaly] {
        var anomalies: [Anomaly] = []
        
        // Check for impossible shift patterns
        if member.shiftsCompletedToday > 4 {
            anomalies.append(.tooManyShifts)
        }
        
        // Check for location impossibilities
        if member.wasAtTwoPlacesSimultaneously {
            anomalies.append(.locationConflict)
        }
        
        // Check for sudden reputation spikes
        if member.pointsThisWeek > member.averageWeeklyPoints * 3 {
            anomalies.append(.reputationSpike)
        }
        
        return anomalies
    }
}
```

### 2. Message Flooding

| Attack | Description | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Spam Flood** | Send millions of messages | Network congestion | Rate limiting |
| **Relay Amplification** | Craft messages that get relayed infinitely | Network collapse | TTL, seen-ID tracking |
| **Large Message Attack** | Send max-size messages continuously | Bandwidth exhaustion | Size limits, quotas |

**Mitigation: Rate Limiting**

```swift
// MARK: - Rate Limiter
class RateLimiter {
    
    struct Limits {
        static let messagesPerMinute = 10
        static let messagesPerHour = 100
        static let messagesPerDay = 500
        static let broadcastsPerHour = 5
        static let emergenciesPerDay = 3
    }
    
    private var messageTimestamps: [String: [Date]] = [:]  // userID -> timestamps
    
    func canSend(userID: String, messageType: MessageType) -> Bool {
        let now = Date()
        let timestamps = messageTimestamps[userID] ?? []
        
        // Check per-minute limit
        let lastMinute = timestamps.filter { now.timeIntervalSince($0) < 60 }
        if lastMinute.count >= Limits.messagesPerMinute {
            return false
        }
        
        // Check per-hour limit
        let lastHour = timestamps.filter { now.timeIntervalSince($0) < 3600 }
        if lastHour.count >= Limits.messagesPerHour {
            return false
        }
        
        // Stricter limits for broadcasts
        if messageType == .broadcast {
            let broadcasts = lastHour.count  // Simplified
            if broadcasts >= Limits.broadcastsPerHour {
                return false
            }
        }
        
        return true
    }
    
    func recordSend(userID: String) {
        var timestamps = messageTimestamps[userID] ?? []
        timestamps.append(Date())
        
        // Prune old timestamps (keep last 24 hours)
        timestamps = timestamps.filter { Date().timeIntervalSince($0) < 86400 }
        messageTimestamps[userID] = timestamps
    }
}
```

### 3. Identity Attacks

| Attack | Description | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Impersonation** | Pretend to be another user | Trust theft | Cryptographic identity |
| **Device Cloning** | Copy device credentials | Duplicate identity | Hardware binding |
| **Key Theft** | Steal private keys | Full account takeover | Secure Enclave |
| **MITM** | Intercept and modify messages | Data corruption | E2E encryption |

**Mitigation: Cryptographic Identity**

```swift
// MARK: - Secure Identity
class SecureIdentity {
    
    // Keys stored in Secure Enclave (hardware-protected)
    private let keychain = KeychainManager()
    
    struct Identity {
        let publicKey: Data      // Shared with others
        let deviceID: String     // Hardware-bound
        let createdAt: Date
        var attestation: Data?   // Device attestation (optional)
    }
    
    /// Generate identity on first launch (keys never leave device)
    func generateIdentity() throws -> Identity {
        // Generate key pair in Secure Enclave
        let privateKey = try SecureEnclave.generatePrivateKey(
            accessControl: .biometryCurrentSet  // Requires biometric
        )
        
        let publicKey = try privateKey.publicKey.rawRepresentation
        
        // Get hardware-bound device ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        // Store in keychain (encrypted, hardware-bound)
        try keychain.store(privateKey, for: "identity.privateKey")
        
        return Identity(
            publicKey: publicKey,
            deviceID: deviceID,
            createdAt: Date()
        )
    }
    
    /// Sign a message (proves identity)
    func sign(_ data: Data) throws -> Data {
        guard let privateKey = try keychain.retrieve("identity.privateKey") else {
            throw IdentityError.noPrivateKey
        }
        
        return try privateKey.signature(for: data)
    }
    
    /// Verify a signature (proves sender identity)
    func verify(_ signature: Data, for data: Data, from publicKey: Data) -> Bool {
        guard let key = try? P256.Signing.PublicKey(rawRepresentation: publicKey) else {
            return false
        }
        
        guard let sig = try? P256.Signing.ECDSASignature(rawRepresentation: signature) else {
            return false
        }
        
        return key.isValidSignature(sig, for: data)
    }
}
```

### 4. Network Attacks

| Attack | Description | Impact | Mitigation |
|--------|-------------|--------|------------|
| **Eclipse Attack** | Surround victim with malicious nodes | Isolation | Multiple transport paths |
| **Selective Relay** | Drop messages from certain users | Censorship | Redundant routing |
| **Timing Attack** | Analyze message timing to deanonymize | Privacy breach | Random delays |
| **Replay Attack** | Resend old valid messages | Confusion | Timestamps, nonces |

**Mitigation: Multi-Path Routing**

```swift
// MARK: - Resilient Routing
class ResilientRouter {
    
    /// Send message via multiple paths for reliability
    func sendWithRedundancy(_ message: Message, redundancy: Int = 3) {
        // Path 1: BLE Mesh
        BLEMeshManager.shared.sendMessage(message.toBLE())
        
        // Path 2: Meshtastic LoRa (if available)
        if MeshtasticManager.shared.isConnected {
            MeshtasticManager.shared.sendMessage(message.toMeshtastic())
        }
        
        // Path 3: CloudKit (if gateway available)
        if CloudSyncManager.shared.isGatewayNode {
            CloudSyncManager.shared.relayToCloud(message.toBLE())
        }
        
        // Path 4: Direct peer (if recipient is connected)
        if let peer = findDirectPeer(message.recipientID) {
            sendDirect(message, to: peer)
        }
    }
    
    /// Detect and report malicious relays
    func detectMaliciousRelay(peer: Peer) -> Bool {
        // Check message drop rate
        let dropRate = peer.messagesDropped / peer.messagesReceived
        if dropRate > 0.5 {
            reportMaliciousPeer(peer)
            return true
        }
        
        // Check selective dropping (e.g., only drops certain senders)
        if peer.hasSelectiveDropPattern {
            reportMaliciousPeer(peer)
            return true
        }
        
        return false
    }
}
```

---

## Security Hardening Recommendations

### 1. Message Security

```swift
// MARK: - Message Security
struct SecureMessage {
    let id: UUID
    let senderPublicKey: Data
    let recipientPublicKey: Data
    let encryptedContent: Data
    let signature: Data
    let timestamp: Date
    let nonce: Data  // Prevents replay
    let ttl: Int     // Time-to-live (hops)
    
    /// Encrypt message for recipient
    static func encrypt(
        content: String,
        for recipientPublicKey: Data,
        from senderPrivateKey: SecureEnclave.P256.Signing.PrivateKey
    ) throws -> SecureMessage {
        // Generate ephemeral key for this message
        let ephemeralKey = P256.KeyAgreement.PrivateKey()
        
        // Derive shared secret
        let recipientKey = try P256.KeyAgreement.PublicKey(rawRepresentation: recipientPublicKey)
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientKey)
        
        // Derive encryption key
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        // Encrypt content
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(content.data(using: .utf8)!, using: symmetricKey, nonce: nonce)
        
        // Sign the encrypted content
        let signature = try senderPrivateKey.signature(for: sealed.ciphertext)
        
        return SecureMessage(
            id: UUID(),
            senderPublicKey: try senderPrivateKey.publicKey.rawRepresentation,
            recipientPublicKey: recipientPublicKey,
            encryptedContent: sealed.combined!,
            signature: signature.rawRepresentation,
            timestamp: Date(),
            nonce: nonce.withUnsafeBytes { Data($0) },
            ttl: 10
        )
    }
}
```

### 2. Trust Scoring

```swift
// MARK: - Trust Score
struct TrustScore {
    
    /// Calculate trust score for a peer (0.0 - 1.0)
    static func calculate(for peer: Peer) -> Double {
        var score = 0.5  // Start neutral
        
        // Factor 1: Message relay reliability
        let relayReliability = peer.messagesRelayed / peer.messagesReceived
        score += (relayReliability - 0.5) * 0.2
        
        // Factor 2: Time in network
        let daysInNetwork = peer.firstSeen.timeIntervalSinceNow / -86400
        score += min(0.1, daysInNetwork / 365 * 0.1)
        
        // Factor 3: Vouches from trusted peers
        let vouchScore = peer.vouches.reduce(0.0) { $0 + $1.voucherTrustScore * 0.05 }
        score += min(0.2, vouchScore)
        
        // Factor 4: Anomaly penalties
        score -= peer.anomalyCount * 0.1
        
        // Factor 5: Verified identity bonus
        if peer.hasVerifiedIdentity {
            score += 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    /// Minimum trust required for different actions
    static let thresholds: [Action: Double] = [
        .receiveMessages: 0.1,
        .relayMessages: 0.3,
        .sendBroadcasts: 0.5,
        .verifyShifts: 0.7,
        .adminActions: 0.9
    ]
}
```

### 3. Anomaly Detection

```swift
// MARK: - Anomaly Detection
class AnomalyDetector {
    
    struct Anomaly {
        let type: AnomalyType
        let severity: Severity
        let evidence: [String: Any]
        let detectedAt: Date
    }
    
    enum AnomalyType {
        case messageFlood
        case locationImpossibility
        case reputationSpike
        case identityConflict
        case relayManipulation
        case timingAnomaly
    }
    
    enum Severity {
        case low      // Log and monitor
        case medium   // Rate limit
        case high     // Temporary ban
        case critical // Permanent ban + alert admins
    }
    
    /// Real-time anomaly detection
    func analyze(event: Event) -> Anomaly? {
        switch event {
        case .messageSent(let message, let sender):
            return detectMessageAnomaly(message, sender)
            
        case .locationUpdate(let location, let user):
            return detectLocationAnomaly(location, user)
            
        case .shiftCompleted(let shift, let user):
            return detectShiftAnomaly(shift, user)
            
        case .peerConnected(let peer):
            return detectPeerAnomaly(peer)
        }
    }
    
    private func detectMessageAnomaly(_ message: Message, _ sender: User) -> Anomaly? {
        // Check for flood
        let recentMessages = sender.messagesSince(Date().addingTimeInterval(-60))
        if recentMessages.count > 20 {
            return Anomaly(
                type: .messageFlood,
                severity: .high,
                evidence: ["count": recentMessages.count, "window": "60s"],
                detectedAt: Date()
            )
        }
        
        // Check for replay
        if messageCache.contains(message.id) {
            return Anomaly(
                type: .timingAnomaly,
                severity: .medium,
                evidence: ["reason": "duplicate_id"],
                detectedAt: Date()
            )
        }
        
        return nil
    }
}
```

---

## Optimization Recommendations

### 1. Database Optimization

```swift
// MARK: - Database Optimization
extension LocalDataManager {
    
    /// Create indexes for common queries
    func createIndexes() {
        // Index on timestamp for time-based queries
        // Index on recipientID for conversation queries
        // Index on senderID for user history
        // Composite index on (recipientID, timestamp) for conversation view
    }
    
    /// Batch operations for efficiency
    func batchInsert(messages: [Message]) {
        persistence.performBackgroundTask { context in
            let batchInsert = NSBatchInsertRequest(
                entity: CachedMessage.entity(),
                objects: messages.map { $0.toDictionary() }
            )
            try? context.execute(batchInsert)
        }
    }
    
    /// Use fetch limits and pagination
    func fetchMessages(page: Int, pageSize: Int = 50) -> [CachedMessage] {
        let request: NSFetchRequest<CachedMessage> = CachedMessage.fetchRequest()
        request.fetchLimit = pageSize
        request.fetchOffset = page * pageSize
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedMessage.timestamp, ascending: false)]
        
        return (try? persistence.viewContext.fetch(request)) ?? []
    }
}
```

### 2. Network Optimization

```swift
// MARK: - Network Optimization
extension BLEMeshManager {
    
    /// Adaptive message compression
    func compress(_ message: BLEMessage) -> Data {
        let json = try! JSONEncoder().encode(message)
        
        // Only compress if beneficial (>100 bytes)
        if json.count > 100 {
            return (try? (json as NSData).compressed(using: .lzfse)) ?? json
        }
        return json
    }
    
    /// Priority queue for messages
    func prioritizedSend() {
        // Sort queue by priority
        messageQueue.sort { priority($0) > priority($1) }
        
        // Send highest priority first
        while let message = messageQueue.first, canSend() {
            sendMessage(message)
            messageQueue.removeFirst()
        }
    }
    
    private func priority(_ message: BLEMessage) -> Int {
        switch message.messageType {
        case .emergency: return 100
        case .deliveryConfirmation: return 80
        case .campAnnouncement: return 60
        case .text: return 40
        case .location: return 20
        }
    }
}
```

### 3. Memory Optimization

```swift
// MARK: - Memory Optimization
class MemoryManager {
    
    static let shared = MemoryManager()
    
    /// Monitor memory pressure
    func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        // Clear caches
        ImageCache.shared.clear()
        
        // Prune relay cache
        BLEMeshManager.shared.pruneRelayCache()
        
        // Release non-essential data
        LocalDataManager.shared.releaseNonEssentialData()
        
        // Force garbage collection
        autoreleasepool { }
    }
    
    /// Lazy loading for large data sets
    func lazyLoadConversations() -> LazySequence<[Conversation]> {
        // Load conversations on-demand as user scrolls
        return conversations.lazy
    }
}
```

---

## Benchmark Targets

### Message Delivery

| Metric | Target | Current | At 10k Users |
|--------|--------|---------|--------------|
| **Latency (same mesh)** | <2s | ~1s | ~5s |
| **Latency (multi-hop)** | <10s | ~5s | ~30s |
| **Delivery Rate** | >95% | ~90% | ~70% |
| **Throughput** | 100 msg/s | ~50 msg/s | ~20 msg/s |

### Storage

| Metric | Target | Current | At 1M Messages |
|--------|--------|---------|----------------|
| **DB Size** | <500 MB | ~50 MB | ~2 GB |
| **Query Time** | <100ms | ~50ms | ~500ms |
| **Insert Time** | <10ms | ~5ms | ~20ms |

### Battery

| Metric | Target | Current |
|--------|--------|---------|
| **Idle Drain** | <2%/hr | ~3%/hr |
| **Active Drain** | <10%/hr | ~8%/hr |
| **Background** | <1%/hr | ~1%/hr |

---

## Disaster Resilience Checklist

### ✅ Works Without Internet
- [x] BLE mesh for local communication
- [x] LoRa mesh for extended range
- [x] Local SQLite storage
- [x] Offline-first architecture

### ✅ Works Without Cellular
- [x] No phone number required
- [x] No SMS verification
- [x] Device-based identity

### ⚠️ Partial: Works Without Cloud
- [x] Core messaging works
- [ ] Social capital sync needs gateway
- [ ] Cross-event history needs sync

### ❌ Needs Work: Works at Scale
- [ ] Message pruning not implemented
- [ ] Rate limiting not implemented
- [ ] Anomaly detection not implemented
- [ ] Trust scoring not implemented

---

## Implementation Priority

### Phase 1: Critical (Before Next Event)
1. **Message Pruning** - Prevent storage exhaustion
2. **Rate Limiting** - Prevent spam floods
3. **Replay Protection** - Add nonces to messages

### Phase 2: Important (Before Scale)
4. **Cryptographic Identity** - Secure Enclave keys
5. **Message Signing** - Prove sender identity
6. **Trust Scoring** - Basic peer reputation

### Phase 3: Hardening (For Production)
7. **Anomaly Detection** - Real-time monitoring
8. **Multi-Path Routing** - Redundant delivery
9. **Shift Verification** - Proof of participation

### Phase 4: Advanced (For Mass Scale)
10. **Sharding** - Split network by geography
11. **Hierarchical Routing** - Reduce hop count
12. **Incentive Alignment** - Reward good actors

---

## Conclusion

The current architecture is solid for **small-to-medium events** (up to ~1,000 users) but needs significant hardening for:

1. **Scale** - Message pruning, database optimization, network sharding
2. **Security** - Cryptographic identity, message signing, anomaly detection
3. **Gaming Prevention** - Shift verification, trust scoring, rate limiting

The good news: the **offline-first, mesh-based architecture** is the right foundation. The work is in hardening, not rebuilding.

---

*Last Updated: January 2026*
