# Robot Heart Security & Privacy

## Overview

Robot Heart is designed with **privacy by design** principles, ensuring that user data remains secure even in a decentralized, peer-to-peer environment. This document explains the security architecture and why users can trust the system.

---

## Security Principles

1. **Local-First Storage** - Your data stays on your device
2. **End-to-End Encryption** - Messages encrypted before leaving your phone
3. **No Central Server** - No single point of attack or surveillance
4. **Minimal Data Collection** - Only what's needed for functionality
5. **User Control** - You decide what to share and with whom
6. **Open Source** - Code is auditable by anyone

---

## Encryption Architecture

### Message Encryption

All messages are encrypted using industry-standard algorithms:

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENCRYPTION FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Sender creates message                                      │
│         │                                                       │
│         ▼                                                       │
│  2. Generate random AES-256 session key                         │
│         │                                                       │
│         ▼                                                       │
│  3. Encrypt message with AES-256-GCM                            │
│     (Authenticated Encryption with Associated Data)             │
│         │                                                       │
│         ▼                                                       │
│  4. Encrypt session key with recipient's public key             │
│     (X25519 Elliptic Curve Diffie-Hellman)                     │
│         │                                                       │
│         ▼                                                       │
│  5. Transmit: [Encrypted Key] + [Encrypted Message] + [Nonce]  │
│         │                                                       │
│         ▼                                                       │
│  6. Recipient decrypts session key with private key             │
│         │                                                       │
│         ▼                                                       │
│  7. Recipient decrypts message with session key                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Cryptographic Algorithms

| Purpose | Algorithm | Key Size | Notes |
|---------|-----------|----------|-------|
| **Key Exchange** | X25519 | 256-bit | Elliptic curve, forward secrecy |
| **Message Encryption** | AES-256-GCM | 256-bit | Authenticated encryption |
| **Password Hashing** | Argon2id | N/A | Memory-hard, GPU-resistant |
| **Message Authentication** | HMAC-SHA256 | 256-bit | Integrity verification |
| **Random Generation** | SecRandomCopyBytes | N/A | iOS secure random |

### Why These Algorithms?

- **X25519**: Used by Signal, WhatsApp, and BitChat. Fast, secure, and resistant to timing attacks.
- **AES-256-GCM**: NSA-approved for TOP SECRET data. Provides both encryption and authentication.
- **Argon2id**: Winner of the Password Hashing Competition. Resistant to GPU/ASIC attacks.

---

## Key Management

### Key Generation

```swift
// Keys generated on first app launch
// Private key NEVER leaves device
// Public key shared with contacts

func generateKeyPair() -> (privateKey: Data, publicKey: Data) {
    var privateKey = Data(count: 32)
    var publicKey = Data(count: 32)
    
    // Generate random private key
    _ = privateKey.withUnsafeMutableBytes { ptr in
        SecRandomCopyBytes(kSecRandomDefault, 32, ptr.baseAddress!)
    }
    
    // Derive public key using X25519
    // ... curve25519 multiplication
    
    return (privateKey, publicKey)
}
```

### Key Storage

| Key Type | Storage Location | Protection |
|----------|------------------|------------|
| **Private Key** | iOS Keychain | Secure Enclave (if available) |
| **Public Keys** | Core Data | Encrypted at rest |
| **Session Keys** | Memory only | Cleared after use |

### Forward Secrecy

Each message uses a unique session key. Even if a private key is compromised:
- Past messages remain secure (can't be decrypted)
- Only future messages are at risk
- Rotating keys periodically limits exposure

---

## Data Privacy

### What Data is Stored Locally

| Data Type | Stored | Encrypted | Expires |
|-----------|--------|-----------|---------|
| Messages | ✅ | ✅ | Configurable |
| Contacts | ✅ | ✅ | Never |
| Location History | ✅ | ✅ | 7 days |
| Profile Info | ✅ | ✅ | Never |
| Pending Messages | ✅ | ✅ | Until delivered |

### What Data is Transmitted

| Data Type | Transmitted | Encrypted | To Whom |
|-----------|-------------|-----------|---------|
| Messages | ✅ | ✅ | Recipient only |
| Presence | ✅ | ❌ | Nearby peers |
| Location | Optional | ✅ | Chosen recipients |
| Camp Info | ✅ | ❌ | All camps |

### What Data is NEVER Collected

- ❌ Phone number
- ❌ Email (unless you choose to share)
- ❌ Contacts list
- ❌ Photos (unless you share)
- ❌ Browsing history
- ❌ App usage analytics
- ❌ Advertising identifiers

---

## Network Security

### BLE Mesh Security

```
┌─────────────────────────────────────────────────────────────────┐
│                    BLE SECURITY LAYERS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Layer 1: BLE Pairing (optional)                                │
│  ├─ LE Secure Connections                                       │
│  └─ ECDH key exchange                                           │
│                                                                 │
│  Layer 2: Application Encryption                                │
│  ├─ X25519 key exchange                                         │
│  ├─ AES-256-GCM message encryption                              │
│  └─ Per-message nonce                                           │
│                                                                 │
│  Layer 3: Message Authentication                                │
│  ├─ GCM authentication tag                                      │
│  └─ Sender signature (optional)                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Relay Node Trust Model

**Problem**: Relay nodes see encrypted messages. Can they be trusted?

**Solution**: They don't need to be trusted.

1. Messages are end-to-end encrypted
2. Relay nodes only see: sender ID, recipient ID, encrypted blob
3. They cannot read content, modify it, or forge messages
4. Even malicious relay nodes can only:
   - Drop messages (detected by delivery confirmation)
   - Delay messages (mitigated by multiple paths)

### Man-in-the-Middle Prevention

```
┌─────────────────────────────────────────────────────────────────┐
│                    KEY VERIFICATION                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Option 1: QR Code Exchange (Recommended)                       │
│  ├─ Meet in person                                              │
│  ├─ Scan each other's QR codes                                  │
│  └─ Keys verified out-of-band                                   │
│                                                                 │
│  Option 2: Safety Number Comparison                             │
│  ├─ App generates safety number from both public keys           │
│  ├─ Compare numbers verbally or via another channel             │
│  └─ If numbers match, no MITM                                   │
│                                                                 │
│  Option 3: Trust on First Use (TOFU)                            │
│  ├─ Accept key on first contact                                 │
│  ├─ Alert if key changes                                        │
│  └─ Less secure but more convenient                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## CloudKit Security

### When Cloud Sync is Used

Cloud sync is **optional** and only occurs when:
1. Device has WiFi/Ethernet connection (e.g., Starlink)
2. User has enabled cloud backup
3. Device acts as gateway node

### CloudKit Security Features

| Feature | Description |
|---------|-------------|
| **Encryption in Transit** | TLS 1.3 to Apple servers |
| **Encryption at Rest** | Apple encrypts all CloudKit data |
| **Access Control** | Only your iCloud account can access |
| **No Apple Access** | Apple cannot read encrypted payloads |

### What's Synced to Cloud

```swift
// Only metadata and encrypted payloads
record["senderID"] = message.senderID           // Visible
record["recipientID"] = message.recipientID     // Visible
record["timestamp"] = message.timestamp         // Visible
record["encryptedPayload"] = encryptedData      // Encrypted (Apple can't read)
```

**Apple can see**: Who sent to whom, when  
**Apple cannot see**: Message content (encrypted before upload)

---

## Threat Model

### Threats We Protect Against

| Threat | Protection |
|--------|------------|
| **Eavesdropping** | End-to-end encryption |
| **Message Tampering** | GCM authentication |
| **Replay Attacks** | Unique message IDs, timestamps |
| **Impersonation** | Public key verification |
| **Device Theft** | iOS Keychain, device passcode |
| **Network Surveillance** | No central server to monitor |
| **Metadata Analysis** | Mesh routing obscures paths |

### Threats We Don't Protect Against

| Threat | Why | Mitigation |
|--------|-----|------------|
| **Compromised Device** | If attacker has your phone, game over | Use strong passcode, Face ID |
| **Rubber Hose Attack** | Physical coercion | Message expiration |
| **Quantum Computing** | Future threat to current crypto | Will upgrade when needed |
| **Traffic Analysis** | Patterns visible on mesh | Use Meshtastic for sensitive |

---

## Privacy Controls

### User-Controlled Settings

```swift
struct PrivacySettings: Codable {
    var shareRealName: Bool = false          // Default: private
    var shareLocation: Bool = false          // Default: private
    var shareContactInfo: Bool = false       // Default: private
    var allowContactRequests: Bool = true    // Default: allow
    var ghostMode: Bool = false              // Hide from map
    var messageExpiration: TimeInterval?     // Auto-delete
}
```

### Contact Request System

```
┌─────────────────────────────────────────────────────────────────┐
│                    CONTACT REQUEST FLOW                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Alice wants to connect with Bob                             │
│         │                                                       │
│         ▼                                                       │
│  2. Alice sends CONTACT REQUEST (public key only)               │
│         │                                                       │
│         ▼                                                       │
│  3. Bob receives request, sees Alice's public info              │
│         │                                                       │
│         ├─► ACCEPT: Exchange keys, can now message              │
│         │                                                       │
│         └─► DECLINE: No data shared, request deleted            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Ghost Mode

When enabled:
- Your location not shared with camp
- You don't appear on camp map
- You can still send/receive messages
- Emergency SOS still works

---

## Audit & Compliance

### Open Source

All code is available for audit:
- GitHub: https://github.com/Art-Technology-Holdings/robot-heart-ios
- License: [To be determined]
- Security issues: Report via GitHub Issues

### No Backdoors

- No government backdoors
- No law enforcement access
- No corporate data mining
- No advertising tracking

### Data Retention

| Data Type | Retention | User Control |
|-----------|-----------|--------------|
| Messages | Until deleted | Can delete anytime |
| Pending Messages | Until delivered or 10 attempts | Automatic |
| Sync Queue | 7 days after sync | Automatic |
| Location History | 7 days | Can disable |

---

## Security Best Practices for Users

### Do

✅ Use a strong device passcode  
✅ Enable Face ID / Touch ID  
✅ Verify contacts via QR code when possible  
✅ Keep iOS updated  
✅ Review privacy settings regularly  
✅ Use Ghost Mode when needed  

### Don't

❌ Share your private key  
❌ Accept contact requests from strangers  
❌ Disable device encryption  
❌ Use on jailbroken devices  
❌ Share sensitive info in broadcast messages  

---

## Incident Response

### If Your Device is Lost/Stolen

1. Use Find My iPhone to locate or wipe
2. Change your iCloud password
3. Notify camp leadership
4. Your encrypted messages remain secure

### If You Suspect Compromise

1. Generate new key pair in app settings
2. Re-verify with important contacts
3. Old messages remain secure (forward secrecy)
4. Report to camp security if needed

---

## Comparison with Other Apps

| Feature | Robot Heart | Signal | WhatsApp | Telegram |
|---------|-------------|--------|----------|----------|
| E2E Encryption | ✅ | ✅ | ✅ | Optional |
| Open Source | ✅ | ✅ | ❌ | Partial |
| No Phone Number | ✅ | ❌ | ❌ | ❌ |
| Works Offline | ✅ | ❌ | ❌ | ❌ |
| No Central Server | ✅ | ❌ | ❌ | ❌ |
| Mesh Networking | ✅ | ❌ | ❌ | ❌ |
| Metadata Protection | ✅ | Partial | ❌ | ❌ |

---

## Technical References

- [X25519 (Curve25519)](https://cr.yp.to/ecdh.html)
- [AES-GCM (NIST SP 800-38D)](https://csrc.nist.gov/publications/detail/sp/800-38d/final)
- [Argon2 (RFC 9106)](https://datatracker.ietf.org/doc/html/rfc9106)
- [Signal Protocol](https://signal.org/docs/)
- [iOS Security Guide](https://support.apple.com/guide/security/welcome/web)
- [CloudKit Security](https://developer.apple.com/documentation/cloudkit/encrypting_user_data)

---

## Contact

Security issues: security@robotheart.camp  
General questions: hello@robotheart.camp  
GitHub: https://github.com/Art-Technology-Holdings/robot-heart-ios
