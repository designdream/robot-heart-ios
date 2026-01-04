# Robot Heart iOS - Project TODO

> **For AI Agents:** Read this file at the start of each session to understand pending work.
> Update task status as you complete items. Add new tasks as they're discovered.

---

## 🔴 Priority 1: Critical / Blocking

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Test Meshtastic with real T1000-E device | `pending` | Device arriving this week | 2026-01-01 |
| Configure Digital Ocean S3 (bucket + keys) | `pending` | Create bucket, generate keys, configure CORS | 2026-01-04 |
| Add camera permission to Info.plist | `done` | Already exists in Info.plist | 2026-01-04 |

---

## 🟠 Priority 2: High / Should Do Soon

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Complete Meshtastic service decomposition | `pending` | Break down MeshtasticManager into focused services | 2026-01-02 |
| Add SwiftProtobuf for full protobuf parsing | `pending` | Current implementation is simplified | 2026-01-01 |
| Add QR scanner to Quick Actions | `done` | Already implemented in PullDownActionsView | 2026-01-04 |
| Integrate QR with real Meshtastic node IDs | `done` | QRCodeManager now uses real node data | 2026-01-04 |
| Add QR code history view | `pending` | Show recently scanned codes | 2026-01-04 |
| Remove extra colors not in Style Guide | `done` | Theme.swift cleaned up to 8 official colors | 2026-01-01 |

---

## 🟡 Priority 3: Medium / Nice to Have

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Simplify navigation (reduce to 4 tabs) | `pending` | UX audit recommendation | 2026-01-01 |
| Add "Next Action" card to Home | `pending` | Personalized prompt for users | 2026-01-01 |
| Implement calendar view for events | `pending` | Currently placeholder | 2026-01-01 |
| Camp-to-camp location sharing via Meshtastic | `pending` | Send camp layout/location to friends | 2026-01-01 |
| Add QR code favorites | `pending` | Frequently used contacts/nodes | 2026-01-04 |
| Add batch QR scanning | `pending` | Scan multiple codes in sequence | 2026-01-04 |
| Add custom QR code styling | `pending` | Robot Heart branding on QR codes | 2026-01-04 |
| CloudKit sync for cross-device | `pending` | Future enhancement | 2026-01-01 |

---

## 🟢 Priority 4: Low / Backlog

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Add unit tests for managers | `pending` | Improve code quality | 2026-01-01 |
| Add UI tests for critical flows | `pending` | Improve reliability | 2026-01-01 |
| Add NFC support | `pending` | Alternative to QR codes | 2026-01-04 |
| Add encrypted QR codes | `pending` | For sensitive data | 2026-01-04 |
| Add QR code analytics | `pending` | Track scans | 2026-01-04 |
| Localization support | `pending` | Future internationalization | 2026-01-01 |
| Dark/Light mode toggle | `pending` | Currently dark only | 2026-01-01 |

---

## ✅ Recently Completed

| Task | Completed | Notes |
|------|-----------|-------|
| Integrate QR with real Meshtastic node IDs | 2026-01-04 | QRCodeManager + QRCodeGeneratorView use real data |
| Remove extra colors not in Style Guide | 2026-01-04 | Theme.swift cleaned to 8 official colors |
| Add QR scanner to Quick Actions | 2026-01-04 | Already implemented in PullDownActionsView |
| Add camera permission to Info.plist | 2026-01-04 | Already exists (NSCameraUsageDescription) |
| Implement AVFoundation QR scanner | 2026-01-04 | Complete with NetworkOrchestrator integration |
| Create QRCodeManager service | 2026-01-04 | Business logic for QR processing |
| Create QRCodeScannerView | 2026-01-04 | SwiftUI camera scanning interface |
| Create QRCodeGeneratorView | 2026-01-04 | QR code generation and sharing |
| Add QRCodeManager to AppEnvironment | 2026-01-04 | Centralized dependency injection |
| Create PROJECT_PLAN.md | 2026-01-04 | High-level project roadmap |
| Add Secure S3 Integration | 2026-01-02 | KeychainService + AWSV4Signer |
| Implement 4-layer network architecture | 2026-01-02 | Cloud + LoRa + BLE + Local |
| Create NetworkOrchestrator | 2026-01-02 | Intelligent routing across layers |
| Create AppEnvironment | 2026-01-02 | Centralized dependency injection |
| Fix Sunset Orange color | 2026-01-02 | Changed to #FF6B35 per style guide |
| Add search to Camp Layout | 2026-01-01 | Search by name/person, highlights matches |
| Consolidate Camp Map + Layout | 2026-01-01 | Single "Camp Layout" in Camp tab |
| Implement full Meshtastic BLE protocol | 2026-01-01 | MeshtasticProtocol.swift + MeshtasticManager.swift |
| Create T1000-E setup documentation | 2026-01-01 | docs/T1000-E_SETUP_GUIDE.md |

---

## 📋 Session Notes

### 2026-01-04 Session (Cleanup & Placeholders)
- **Cleaned up Theme.swift**: Removed non-official colors (deepRedOrange, amber, dustyPink, ledMagenta)
- **Updated COLOR_PALETTE.md**: Aligned with STYLE_GUIDE.md official 8 colors
- **Replaced placeholder node IDs**: QRCodeManager now uses real Meshtastic data
- **Fixed QRCodeGeneratorView**: Uses QRCodeManager methods instead of hardcoded placeholders
- **Verified existing features**: Camera permissions and QR Quick Actions already implemented
- **Updated TODO.md**: Marked 4 tasks as done, moved to Recently Completed

### 2026-01-04 Session (Earlier)
- **QR Code Scanner Complete**
- Implemented `QRCodeScanner` service with AVFoundation
- Implemented `QRCodeManager` with NetworkOrchestrator integration
- Created `QRCodeScannerView` and `QRCodeGeneratorView`
- Added QR data models: `QRContact`, `QRMeshNode`, `QRCampInvite`
- Integrated with AppEnvironment
- Added QR follow-up tasks to TODO
- Created `PROJECT_PLAN.md` with comprehensive roadmap

### 2026-01-02 Session (Phase 2 - S3 Security)
- **Secure S3 Integration Complete**
- Implemented `KeychainService` for secure credential storage
- Implemented `AWSV4Signer` for AWS Signature V4 authentication
- Created `S3SettingsView` for user credential configuration
- Updated `CloudSyncService` to use Keychain and AWS V4
- Created comprehensive `S3_INTEGRATION_GUIDE.md`
- Added `updateS3Credentials()` to AppEnvironment

### 2026-01-02 Session (Phase 2 - Network Architecture)
- **4-Layer Network Architecture Complete**
- Designed comprehensive multi-layer strategy (Cloud → LoRa → BLE → Local)
- Implemented `CloudSyncService` with Digital Ocean S3 integration
- Added automatic gateway node promotion (devices with internet bridge mesh ↔ cloud)
- Implemented store-and-forward with exponential backoff retry
- Updated `NetworkOrchestrator` for 4-layer intelligent routing
- Emergency messages now broadcast via ALL available layers (redundancy)
- Created `docs/NETWORK_LAYERS.md` with complete architecture documentation
- Started Meshtastic service decomposition (`MeshtasticConnectionService`)
- Cost-effective: <$1/month for 10,000 messages/day on Digital Ocean

### 2026-01-02 Session (Phase 1)
- **Phase 1 Architectural Refactoring Complete**
- Created `AppEnvironment` for centralized dependency injection (replaces 22 individual managers)
- Created `NetworkOrchestrator` to manage Meshtastic + BLE coexistence and prevent conflicts
- Fixed Sunset Orange color to match style guide (#FF6B35)
- Created comprehensive refactoring guide (`docs/REFACTORING_GUIDE.md`)
- Simplified `RobotHeartApp.swift` significantly
- Added network health monitoring and intelligent routing

### 2026-01-01 Session (Evening)
- Added search functionality to Camp Layout (search by name/person, highlights matches, grays out rest)
- Consolidated Camp Map + Camp Layout into single feature
- Removed upload map functionality (clean playa sand background)
- Created TODO.md task tracking framework
- Researched Meshtastic data transmission limits (237 bytes max payload)

### 2026-01-01 Session (Earlier)
- Completed Meshtastic BLE implementation (real, not mock)
- Created T1000-E setup guide
- Conducted UX audit - found navigation clutter
- Conducted color audit - found Sunset Orange mismatch
- Device arriving this week for testing

---

## How to Use This File

### For AI Agents
1. **Read at session start** - Understand what's pending
2. **Pick tasks by priority** - Red > Orange > Yellow > Green
3. **Update status** - Change `pending` → `in_progress` → `done`
4. **Add discovered tasks** - New issues found during work
5. **Add session notes** - Brief summary of what was done

### Status Values
- `pending` - Not started
- `in_progress` - Currently being worked on
- `blocked` - Waiting on something
- `done` - Completed (move to Recently Completed)

### Priority Levels
- 🔴 **P1 Critical** - Blocking issues, must fix
- 🟠 **P2 High** - Important, do soon
- 🟡 **P3 Medium** - Nice to have
- 🟢 **P4 Low** - Backlog, someday

---

*Last updated: 2026-01-04*
