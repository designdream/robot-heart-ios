# Social Capital Token Economy

## Vision

Transform Social Capital from a simple points system into **lightweight cryptographic tokens** that can be:
- Earned through participation (shifts, tasks, contributions)
- Gifted to others (supporting Burning Man's gifting principle)
- Redeemed for camp resources (in a cashless economy)
- Verified offline via mesh network

## Design Principles

### 1. Burning Man Aligned
- **Decommodification**: Tokens cannot be bought with money
- **Gifting**: Tokens can be freely given to others
- **Participation**: Only earned through contribution
- **Communal Effort**: Supports camp operations

### 2. Edge-First Architecture
- **Lightweight**: Minimal CPU, memory, storage footprint
- **Offline-capable**: Works without internet
- **Mesh-verifiable**: Tokens validated via peer consensus
- **Battery-efficient**: No heavy cryptographic operations

### 3. Trust Without Central Authority
- **Signed by contributors**: Each token signed by earner
- **Witnessed by peers**: Mesh nodes witness transactions
- **Tamper-evident**: Invalid tokens rejected by network
- **Recoverable**: Can restore from mesh peers

## Token Structure

```swift
struct SocialCapitalToken: Codable, Identifiable {
    let id: UUID
    let amount: Int                    // Points value
    let earnedBy: String               // Member ID who earned it
    let earnedFor: ContributionType    // What was done
    let timestamp: Date                // When earned
    let signature: Data                // Cryptographic signature
    let witnesses: [WitnessSignature]  // Peer attestations
    
    enum ContributionType: String, Codable {
        case shift          // Completed a shift
        case task           // Completed a task
        case gift           // Received as gift
        case bonus          // Special recognition
    }
}

struct WitnessSignature: Codable {
    let witnessID: String      // Peer who witnessed
    let timestamp: Date        // When witnessed
    let signature: Data        // Their attestation
}
```

## Earning Tokens

| Action | Base Tokens | Multipliers |
|--------|-------------|-------------|
| Bus Shift | 10 | Night: 1.5x, Peak Heat: 1.4x |
| Shady Bot Shift | 12 | Late Week: 1.2x |
| Camp Shift | 8 | Teardown: 2.0x |
| P1 Task | 15 | Urgent: +5 bonus |
| P2 Task | 10 | - |
| P3 Task | 5 | - |
| Gift Received | Variable | - |

## Gifting Flow

```
Alice completes shift → Earns 10 tokens (signed by Alice, witnessed by shift lead)
                     ↓
Alice gifts 5 tokens to Bob → Creates gift transaction (signed by Alice)
                           ↓
Bob receives 5 tokens → His balance increases, mesh propagates
```

### Gift Transaction
```swift
struct GiftTransaction: Codable {
    let id: UUID
    let from: String           // Giver's member ID
    let to: String             // Recipient's member ID
    let amount: Int            // Tokens gifted
    let message: String?       // Optional note
    let timestamp: Date
    let signature: Data        // Giver's signature
}
```

## Redemption (Camp Resources)

Tokens can be redeemed for camp resources in a **cashless economy**:

| Resource | Token Cost | Notes |
|----------|------------|-------|
| Ice | 2 | When available |
| Water Refill | 1 | Unlimited |
| Meal | 5 | Camp meals |
| Bike Rental | 10/day | If available |
| Priority Shift Pick | 20 | Draft advantage |
| Camp Swag | 15-50 | T-shirts, etc. |

### Redemption Flow
```
Bob has 25 tokens → Redeems 5 for meal → Camp lead confirms
                                      ↓
                 Redemption recorded → Bob's balance: 20 tokens
```

## Offline Verification

### Challenge-Response Protocol
```
1. Bob claims he has 25 tokens
2. Alice's device challenges: "Prove token #xyz"
3. Bob's device responds with token + signatures
4. Alice's device verifies signatures locally
5. If valid, transaction proceeds
```

### Mesh Consensus
- Tokens propagate through mesh network
- Each node maintains local ledger
- Conflicts resolved by timestamp + witness count
- Majority consensus determines truth

## Implementation Phases

### Phase 1: Points System (Current)
- ✅ Points earned for shifts/tasks
- ✅ Leaderboard and trust levels
- ✅ Local storage

### Phase 2: Signed Tokens
- [ ] Generate keypair per user
- [ ] Sign earned tokens
- [ ] Verify signatures locally
- [ ] Store in secure enclave

### Phase 3: Gifting
- [ ] Gift transaction UI
- [ ] Transfer tokens between users
- [ ] Gift history and notifications

### Phase 4: Mesh Verification
- [ ] Propagate tokens via mesh
- [ ] Witness protocol
- [ ] Conflict resolution
- [ ] Offline verification

### Phase 5: Redemption
- [ ] Resource catalog
- [ ] Redemption flow
- [ ] Camp lead confirmation
- [ ] Audit trail

## Technical Considerations

### Cryptography (Lightweight)
- **Ed25519**: Fast, small signatures (64 bytes)
- **No blockchain**: Too heavy for mobile/mesh
- **Secure Enclave**: Store private keys safely
- **Deterministic**: Same input = same output

### Storage
- **SQLite**: Efficient local storage
- **Pruning**: Old tokens archived after event
- **Sync**: Merge with mesh peers on connect

### Battery
- **Lazy verification**: Only verify on demand
- **Batch operations**: Group crypto ops
- **Sleep-friendly**: No background crypto

## Security Model

### Threat: Token Forgery
- **Mitigation**: Signatures require private key
- **Detection**: Invalid signatures rejected

### Threat: Double Spending
- **Mitigation**: Mesh consensus, witness requirement
- **Detection**: Conflicting transactions flagged

### Threat: Replay Attack
- **Mitigation**: Unique IDs, timestamps
- **Detection**: Duplicate tokens rejected

### Threat: Key Theft
- **Mitigation**: Secure Enclave storage
- **Recovery**: Revoke old key, issue new tokens

## UX Principles

1. **Invisible Complexity**: Users see points, not crypto
2. **Instant Feedback**: Earn/gift feels immediate
3. **Trust Indicators**: Show verification status subtly
4. **Graceful Degradation**: Works even if crypto fails

## Future Extensions

- **Cross-Camp Economy**: Trade tokens between camps
- **Multi-Event Persistence**: Carry reputation across years
- **Skill Badges**: NFT-like achievements (lightweight)
- **Governance Voting**: Token-weighted decisions

---

*This document outlines a future vision. Current implementation uses simple points.*
