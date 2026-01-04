# Robot Heart Resilient Communications Plan

**Date**: 2026-01-04  
**Status**: Research Complete, Implementation Planned  
**Goal**: Year-round communication that works on/off playa, survives disasters

---

## Executive Summary

Based on research from:
- **Burners Without Borders** - Meshtastic at Burning Man 2025
- **Burning Mesh** - Official BM Meshtastic deployment (1,606 nodes, 28K+ packets/day)
- **Hurricane Helene Response** - 120 radios deployed in Tennessee/NC
- **Hurricane Ian Response** - Southwest Florida mesh networks
- **Hackaday Community** - Disaster preparedness use cases
- **Meshtastic Official Docs** - MQTT gateway integration

### Key Insight

**Satellites will likely continue when cell towers fail.** Our architecture should:
1. Work 100% offline (mesh only)
2. Auto-upgrade when Starlink/WiFi available
3. Bridge mesh ↔ cloud via gateway nodes
4. Store-and-forward for 7+ days

---

## Hardware Recommendations

### Tier 1: Personal Devices (EDC - Every Day Carry)

| Device | Price | Battery | Screen | Best For |
|--------|-------|---------|--------|----------|
| **SenseCAP T1000-E** | ~$40 | 700mAh (3-7 days) | None | Tracking, compact |
| **RAK WisMesh Pocket** | ~$60 | 3000mAh (7+ days) | OLED | Messages, long battery |
| **LILYGO T-Echo** | ~$50 | 850mAh | E-Ink | Sunlight readable |

**Recommendation**: SenseCAP T1000-E for most users (credit card sized, 7 days battery with GPS off)

### Tier 2: Base Station / Repeater Nodes

| Device | Price | Power | Range | Best For |
|--------|-------|-------|-------|----------|
| **RAK WisMesh Hub** | ~$80 | Solar/USB | 5-15km | Camp base station |
| **Heltec V3** | ~$25 | USB | 3-10km | Budget repeater |
| **Station G1** | ~$150 | USB (3.5W TX) | 15-30km | Long-range backbone |

**Recommendation**: RAK WisMesh Hub with solar panel for camp infrastructure

### Tier 3: Gateway Nodes (Mesh ↔ Internet Bridge)

| Device | Price | Connectivity | Best For |
|--------|-------|--------------|----------|
| **RAK WisMesh Ethernet Gateway** | ~$114 | Ethernet/MQTT | Starlink bridge |
| **Any node + WiFi** | Variable | WiFi/MQTT | Camp WiFi bridge |
| **Phone as Gateway** | $0 | Cellular/WiFi | Mobile gateway |

**Recommendation**: RAK WisMesh Ethernet Gateway connected to Starlink

---

## Network Architecture

### Year-Round Operation Modes

```
┌─────────────────────────────────────────────────────────────────┐
│                    NORMAL MODE (City/Home)                       │
│                                                                  │
│  Phone ←→ Cloud API ←→ Other Users                              │
│    ↓                                                            │
│  BLE Mesh (presence detection, nearby users)                    │
│                                                                  │
│  Meshtastic: Standby (conserve battery)                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PLAYA MODE (Burning Man)                      │
│                                                                  │
│  Phone ←→ Meshtastic ←→ Camp Mesh ←→ Playa-wide Mesh           │
│                              ↓                                   │
│                    Gateway Node (Starlink)                       │
│                              ↓                                   │
│                         Cloud API                                │
│                              ↓                                   │
│                    Other Camps / Off-playa                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    DISASTER MODE (No Internet)                   │
│                                                                  │
│  Phone ←→ Meshtastic ←→ Local Mesh ←→ Repeaters                │
│                                                                  │
│  Cloud: Unavailable (queued for later)                          │
│  BLE: Active (nearby presence)                                  │
│  Local Storage: All messages cached                             │
└─────────────────────────────────────────────────────────────────┘
```

### Gateway Node Strategy

**Problem from BWB Report**: "No multi-tenancy" - nodes tied to single user

**Our Solution**: Any device with internet becomes a gateway automatically

```swift
// Auto-promotion logic (already in NetworkOrchestrator)
if hasInternetConnectivity() {
    becomeGatewayNode()
    // Relay: Mesh → Cloud
    // Relay: Cloud → Mesh
}
```

**Multiple Gateways**: When Starlink is available at camp:
- All phones on WiFi become gateways
- Dedicated RAK Ethernet Gateway as primary
- Cloud deduplicates by message ID
- Redundancy = reliability

---

## Lessons from Real Deployments

### Burning Man 2025 (via BWB & Burning Mesh)

| What Worked | What Failed |
|-------------|-------------|
| 1,606 nodes active | iOS app hangs with message backlog |
| 28,817 packets/day peak | GPS/maps broken on public channel |
| 3.5% channel utilization | No find-person/direction feature |
| 7 days on solar | Node setup too complex |
| Zero dropped packets (camp) | Storm damage to router nodes |

**Key Learnings**:
1. Use **Burning Mesh firmware** (optimized for playa)
2. **Never share location on public channel** (spam + privacy)
3. **Disable GPS when not needed** (battery life)
4. **E-Ink screens** better in desert sun
5. **Redundant router nodes** (storms will kill some)

### Hurricane Helene (Tennessee/NC)

| Deployment | Result |
|------------|--------|
| 120 radios to volunteers | Search & rescue coordination |
| Peak: 400 nodes in Florida | Successful message relay |
| Use case: "Where is gas/water?" | Critical info sharing |

**Key Learnings**:
1. **Pre-position nodes** before disaster
2. **Simple setup** is critical (people are stressed)
3. **Text messaging** is the killer app (not maps)
4. **Solar power** essential (grid down for days)

### Hurricane Ian (Southwest Florida)

**Quote from local operator**:
> "When a hurricane happens, I'm out finding where there's water, fuel — any necessities. People with no comms at all can't call to ask if gas stations are open. We can broadcast that information over the network."

**Key Learnings**:
1. **Community info sharing** is primary use case
2. **100+ mile range** possible with elevation
3. **No license required** (unlike ham radio)
4. **Open source = no single point of failure**

---

## MQTT Bridge Architecture

### How It Works

```
┌──────────────┐     LoRa      ┌──────────────┐
│   Mobile     │ ←──────────→  │   Gateway    │
│   Node       │               │   Node       │
└──────────────┘               └──────┬───────┘
                                      │ WiFi/Ethernet
                                      ▼
                               ┌──────────────┐
                               │  MQTT Broker │
                               │  (Private)   │
                               └──────┬───────┘
                                      │
                    ┌─────────────────┼─────────────────┐
                    ▼                 ▼                 ▼
             ┌──────────┐      ┌──────────┐      ┌──────────┐
             │ Cloud DB │      │ Home     │      │ Other    │
             │ (S3/API) │      │ Assistant│      │ Gateways │
             └──────────┘      └──────────┘      └──────────┘
```

### Our Implementation

**Current** (from NETWORK_LAYERS.md):
- Layer 1: Cloud (HTTPS/WebSocket) ✅
- Layer 2: Meshtastic (LoRa) ✅
- Layer 3: BLE Mesh ✅
- Layer 4: Local Storage ✅

**Enhancement Needed**:
- Add MQTT support for Meshtastic gateway integration
- Use private MQTT broker (not public Meshtastic server)
- Bridge to our Cloud API

### MQTT Topic Structure

```
robotheart/US/2/json/{channel}/{nodeId}

Examples:
robotheart/US/2/json/camp/!abc123      # Camp channel messages
robotheart/US/2/json/emergency/!abc123  # Emergency broadcasts
robotheart/US/2/json/dm/!abc123        # Direct messages
```

---

## Implementation Roadmap

### Phase 1: Firmware & Device Support (Priority: HIGH)

| Task | Status | Notes |
|------|--------|-------|
| Add Burning Mesh firmware detection | 🔴 TODO | Warn if not optimized |
| Support SenseCAP T1000-E | ✅ Done | Primary device in protocol |
| Support RAK WisMesh devices | ✅ Done | In MeshtasticProtocol.swift |
| Add device setup wizard | 🔴 TODO | Simplify onboarding |

### Phase 2: iOS Performance (Priority: HIGH)

| Task | Status | Notes |
|------|--------|-------|
| Message pagination | 🔴 TODO | Prevent app hangs |
| Limit in-memory messages | 🔴 TODO | Max 100 per channel |
| Background message processing | 🔴 TODO | Don't block UI |
| Efficient message deduplication | 🔴 TODO | Track seen IDs |

### Phase 3: Find-Person Features (Priority: MEDIUM)

| Task | Status | Notes |
|------|--------|-------|
| Direction-to-node compass | 🔴 TODO | Top user request |
| Last-seen location history | 🔴 TODO | 24-hour rolling |
| Distance indicator | 🔴 TODO | "500m away" |
| Location sharing warnings | 🔴 TODO | Privacy protection |

### Phase 4: Gateway Integration (Priority: MEDIUM)

| Task | Status | Notes |
|------|--------|-------|
| MQTT client integration | 🔴 TODO | For gateway nodes |
| Private broker support | 🔴 TODO | Not public server |
| Auto-gateway promotion | ✅ Done | In NetworkOrchestrator |
| Cross-gateway deduplication | ✅ Done | By message ID |

### Phase 5: Disaster Preparedness (Priority: LOW)

| Task | Status | Notes |
|------|--------|-------|
| Node diagnostics view | 🔴 TODO | Debug connection issues |
| Channel utilization monitor | 🔴 TODO | Detect congestion |
| Battery optimization mode | 🔴 TODO | Extend life in emergencies |
| Offline map caching | 🔴 TODO | BRC grid + local area |

---

## Recommended Hardware Kit

### Per-Person Kit (~$50)

- 1x SenseCAP T1000-E ($40)
- 1x Lanyard/clip ($5)
- 1x USB-C cable ($5)

### Per-Camp Kit (~$300)

- 1x RAK WisMesh Hub + solar ($100)
- 1x RAK Ethernet Gateway ($114)
- 2x SenseCAP T1000-E for spares ($80)
- Mounting hardware ($20)

### Disaster Prep Kit (~$200)

- 3x Heltec V3 nodes ($75)
- 1x 10dBi external antenna ($50)
- 1x Solar panel + battery ($50)
- Weatherproof enclosure ($25)

---

## Configuration Recommendations

### Burning Man Settings

```
Region: US
Modem Preset: LONG_FAST (default for BM)
Hop Limit: 3 (default)
GPS: Disabled (unless tracking needed)
Position Broadcast: PRIVATE CHANNEL ONLY
Bluetooth PIN: Change from default 123456
```

### Disaster Settings

```
Region: US
Modem Preset: LONG_SLOW (max range)
Hop Limit: 5 (extended reach)
GPS: Enabled (for location sharing)
Position Broadcast: Private channel
Power: Low TX when possible
```

### Urban/Daily Settings

```
Region: US
Modem Preset: SHORT_FAST (quick messages)
Hop Limit: 3
GPS: Disabled (battery)
BLE: Enabled (presence)
WiFi: Enabled (gateway mode)
```

---

## Security Considerations

### Encryption

- **AES-256** encryption on all channels
- **Private PSK** for camp channels (not default)
- **No encryption** required for ham operators (higher power)

### Privacy

- **Never broadcast location on public channel**
- **Use private channels** for camp communication
- **Ghost mode** for location privacy
- **Message TTL** for auto-deletion

### Operational Security

- **Change default Bluetooth PIN** (123456 → random)
- **Use unique channel names** (not "general")
- **Rotate PSK** periodically
- **Don't rely solely on mesh** for emergencies

---

## Conclusion

Our 4-layer architecture is **well-aligned** with real-world Meshtastic deployments. Key enhancements needed:

1. **iOS Performance** - Prevent app hangs with message pagination
2. **Find-Person** - Add direction/distance features (top user request)
3. **Firmware Guidance** - Help users flash Burning Mesh firmware
4. **MQTT Gateway** - Bridge to private broker for cross-network comms

The system is designed to:
- ✅ Work year-round (city, playa, disaster)
- ✅ Survive cell tower outages
- ✅ Auto-upgrade when Starlink/WiFi available
- ✅ Store messages for 7+ days
- ✅ Scale to 1,000+ nodes

**Satellites will continue** - our gateway architecture leverages this by auto-promoting any internet-connected device to bridge the mesh to the cloud.

---

*References:*
- https://burnerswithoutborders.org/projects/meshtastic-meets-burning-man/
- https://burningmesh.org
- https://docs.burningmesh.org
- https://meshtastic.org/docs/software/integrations/mqtt/
- https://hackaday.com/2023/06/26/meshtastic-for-the-greater-good/
- https://store.rokland.com/blogs/news/the-best-meshtastic-node-for-burning-man
