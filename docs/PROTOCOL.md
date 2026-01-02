# Robot Heart Protocol Specification

## Overview

This document specifies the Robot Heart communication protocol used for peer-to-peer messaging, camp discovery, and multi-camp coordination. The protocol is designed to work across multiple transport layers (BLE, LoRa, CloudKit).

---

## Protocol Version

**Current Version:** 1.0  
**Status:** Draft  
**Last Updated:** January 2026

---

## Transport Layers

### Layer 1: BLE (Bluetooth Low Energy)

**Service UUID:** `RH01B218-15A8-461F-9FA8-5DCAE273EAFD`

| Characteristic | UUID | Properties | Purpose |
|----------------|------|------------|---------|
| Message | `RH02C69E-4993-11ED-B878-0242AC120002` | Read, Write, Notify | Send/receive messages |
| Presence | `RH03D6D2-129E-4DAD-A1DD-7866124401E7` | Read | Broadcast user info |

**Advertising Data:**
```
Local Name: "RH-{username}" (max 8 chars after prefix)
Service UUIDs: [RH01B218-15A8-461F-9FA8-5DCAE273EAFD]
```

### Layer 2: Meshtastic (LoRa)

**PortNum:** 256 (PRIVATE_APP)

Messages are JSON-encoded and must fit within ~200 bytes after protobuf overhead.

### Layer 3: CloudKit

**Container:** `iCloud.com.robotheart.app`  
**Database:** Private  
**Record Types:** Message, Member, Camp

---

## Message Format

### BLE Message

```json
{
  "id": "uuid-string",
  "senderID": "uuid-string",
  "senderName": "string (max 32 chars)",
  "recipientID": "uuid-string or 'broadcast'",
  "messageType": "text|location|deliveryConfirmation|campAnnouncement|emergency",
  "content": "string (max 1000 chars for BLE, 150 for LoRa)",
  "timestamp": "ISO8601 date string",
  "locationLat": "double (optional)",
  "locationLon": "double (optional)"
}
```

### Compact Message (for Meshtastic)

Due to LoRa bandwidth constraints, messages are compacted:

```json
{
  "id": "8-char-prefix",
  "from": "8-char-prefix",
  "to": "8-char-prefix",
  "type": "t|l|d|c|e",
  "content": "string (max 150 chars)",
  "lat": "double (optional)",
  "lon": "double (optional)"
}
```

**Type Codes:**
- `t` = text
- `l` = location
- `d` = delivery confirmation
- `c` = camp announcement
- `e` = emergency

---

## Message Types

### 1. Text Message

Standard text message between users.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "senderID": "user-123",
  "senderName": "Dusty Dave",
  "recipientID": "user-456",
  "messageType": "text",
  "content": "Meet me at the bus at sunset!",
  "timestamp": "2026-08-28T19:30:00Z"
}
```

### 2. Location Share

Share current GPS location with a user or broadcast.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "senderID": "user-123",
  "senderName": "Dusty Dave",
  "recipientID": "user-456",
  "messageType": "location",
  "content": "7:30 & G",
  "timestamp": "2026-08-28T19:30:00Z",
  "locationLat": 40.7864,
  "locationLon": -119.2065
}
```

### 3. Delivery Confirmation

Sent back to confirm message receipt.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440002",
  "senderID": "user-456",
  "senderName": "Playa Princess",
  "recipientID": "user-123",
  "messageType": "deliveryConfirmation",
  "content": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-08-28T19:30:05Z"
}
```

The `content` field contains the ID of the message being confirmed.

### 4. Camp Announcement

Broadcast camp information for discovery.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440003",
  "senderID": "user-123",
  "senderName": "Dusty Dave",
  "recipientID": "broadcast",
  "messageType": "campAnnouncement",
  "content": "{\"campID\":\"camp-789\",\"name\":\"Robot Heart\",\"location\":\"7:30 & G\",\"memberCount\":150}",
  "timestamp": "2026-08-28T19:30:00Z",
  "locationLat": 40.7864,
  "locationLon": -119.2065
}
```

### 5. Emergency Alert

High-priority emergency broadcast with location.

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440004",
  "senderID": "user-123",
  "senderName": "Dusty Dave",
  "recipientID": "broadcast",
  "messageType": "emergency",
  "content": "Medical emergency - need help!",
  "timestamp": "2026-08-28T19:30:00Z",
  "locationLat": 40.7864,
  "locationLon": -119.2065
}
```

---

## Camp Protocol

### Camp Protocol Message

Wrapper for all camp-to-camp communication.

```json
{
  "version": 1,
  "type": "ping|announce|chat|resource|event|emergency",
  "campID": "uuid-string",
  "senderID": "uuid-string",
  "timestamp": "ISO8601 date string",
  "payload": "base64-encoded type-specific data (optional)"
}
```

### Message Types

#### Discovery Ping

Request nearby camps to announce themselves.

```json
{
  "version": 1,
  "type": "ping",
  "campID": "camp-789",
  "senderID": "user-123",
  "timestamp": "2026-08-28T19:30:00Z",
  "payload": null
}
```

#### Camp Announcement

Response to ping or periodic broadcast.

```json
{
  "version": 1,
  "type": "announce",
  "campID": "camp-789",
  "senderID": "user-123",
  "timestamp": "2026-08-28T19:30:00Z",
  "payload": "eyJjYW1wSUQiOiJjYW1wLTc4OSIsIm5hbWUiOiJSb2JvdCBIZWFydCIsImxvY2F0aW9uIjoiNzozMCAmIEciLCJtZW1iZXJDb3VudCI6MTUwfQ=="
}
```

Payload (decoded):
```json
{
  "campID": "camp-789",
  "name": "Robot Heart",
  "location": "7:30 & G",
  "memberCount": 150,
  "description": "Sound camp with sunrise sets"
}
```

#### Resource Request

Request resources from nearby camps.

```json
{
  "version": 1,
  "type": "resource",
  "campID": "camp-789",
  "senderID": "user-123",
  "timestamp": "2026-08-28T19:30:00Z",
  "payload": "eyJpZCI6InJlcS0xMjMiLCJjYW1wSUQiOiJjYW1wLTc4OSIsImNhbXBOYW1lIjoiUm9ib3QgSGVhcnQiLCJyZXNvdXJjZVR5cGUiOiJ3YXRlciIsImRlc2NyaXB0aW9uIjoiTmVlZCAyMCBnYWxsb25zIG9mIHdhdGVyIn0="
}
```

Payload (decoded):
```json
{
  "id": "req-123",
  "campID": "camp-789",
  "campName": "Robot Heart",
  "resourceType": "water",
  "description": "Need 20 gallons of water",
  "timestamp": "2026-08-28T19:30:00Z"
}
```

#### Event Broadcast

Announce an event to nearby camps.

```json
{
  "version": 1,
  "type": "event",
  "campID": "camp-789",
  "senderID": "user-123",
  "timestamp": "2026-08-28T19:30:00Z",
  "payload": "eyJpZCI6ImV2dC0xMjMiLCJjYW1wSUQiOiJjYW1wLTc4OSIsImNhbXBOYW1lIjoiUm9ib3QgSGVhcnQiLCJ0aXRsZSI6IlN1bnJpc2UgU2V0IiwiZGVzY3JpcHRpb24iOiJEYW5jZSB3aXRoIHVzISIsInRpbWUiOiIyMDI2LTA4LTI5VDA1OjMwOjAwWiIsImxvY2F0aW9uIjoiUm9ib3QgSGVhcnQgQnVzIn0="
}
```

Payload (decoded):
```json
{
  "id": "evt-123",
  "campID": "camp-789",
  "campName": "Robot Heart",
  "title": "Sunrise Set",
  "description": "Dance with us!",
  "time": "2026-08-29T05:30:00Z",
  "location": "Robot Heart Bus"
}
```

---

## Presence Data

Broadcast when advertising via BLE.

```json
{
  "userID": "uuid-string",
  "userName": "string (max 32 chars)",
  "campID": "uuid-string (optional)",
  "timestamp": "ISO8601 date string"
}
```

---

## Relay Behavior

### Message Relay Rules

1. **Check Duplicate**: If message ID seen before, ignore
2. **Check Recipient**: If message is for us, process it
3. **Relay**: Forward to all connected peers except sender
4. **Track**: Add message ID to seen set (max 1000, LRU eviction)

### Relay Pseudocode

```swift
func handleMessage(_ message: BLEMessage, from sender: String) {
    // 1. Duplicate check
    guard !seenMessageIDs.contains(message.id) else { return }
    seenMessageIDs.insert(message.id)
    
    // 2. Check if for us
    if message.recipientID == myID || message.recipientID == "broadcast" {
        processMessage(message)
        
        // Send delivery confirmation (not for broadcasts)
        if message.recipientID == myID {
            sendDeliveryConfirmation(for: message)
        }
    }
    
    // 3. Relay to others
    for peer in connectedPeers where peer.id != sender {
        send(message, to: peer)
    }
}
```

---

## Store-and-Forward

### Pending Message States

| State | Description |
|-------|-------------|
| `pending` | Awaiting delivery |
| `delivered` | Delivery confirmed |
| `failed` | Max retries exceeded |

### Retry Schedule

```
Attempt 1: Immediate
Attempt 2: +30 seconds
Attempt 3: +45 seconds (30 * 1.5)
Attempt 4: +67 seconds (45 * 1.5)
...
Attempt 10: +1154 seconds
Total: ~57 minutes
```

After 10 failed attempts, message marked as `failed` but retained locally.

---

## Security

### Encryption (Future)

Messages should be encrypted using:
- **Key Exchange**: X25519
- **Encryption**: AES-256-GCM
- **Nonce**: 12 bytes, unique per message

### Message Authentication

GCM provides authentication. Additionally:
- Timestamp prevents replay (reject if >24 hours old)
- Message ID prevents duplicates

---

## Error Handling

### Error Codes

| Code | Description |
|------|-------------|
| `E001` | Invalid message format |
| `E002` | Unknown message type |
| `E003` | Recipient not found |
| `E004` | Message too large |
| `E005` | Encryption failed |
| `E006` | Decryption failed |

---

## Versioning

Protocol version is included in camp protocol messages. Clients should:
1. Accept messages with version <= current
2. Ignore messages with version > current (forward compatibility)
3. Include version in all outgoing messages

---

## Implementation Notes

### iOS (Swift)

```swift
// Encoding
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let data = try encoder.encode(message)

// Decoding
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let message = try decoder.decode(BLEMessage.self, from: data)
```

### Size Limits

| Transport | Max Message Size |
|-----------|------------------|
| BLE | 512 bytes |
| Meshtastic | 200 bytes |
| CloudKit | Unlimited |

---

## References

- [Bluetooth Core Specification](https://www.bluetooth.com/specifications/specs/)
- [Meshtastic Protocol](https://meshtastic.org/docs/development/reference/protobufs/)
- [JSON Specification](https://www.json.org/)
- [ISO 8601 Date Format](https://www.iso.org/iso-8601-date-and-time-format.html)
