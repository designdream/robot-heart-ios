# Robot Heart iOS - Project TODO

> **For AI Agents:** Read this file at the start of each session to understand pending work.
> Update task status as you complete items. Add new tasks as they're discovered.

---

## 🔴 Priority 1: Critical / Blocking

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Test Meshtastic with real T1000-E device | `pending` | Device arriving this week | 2026-01-01 |

---

## 🟠 Priority 2: High / Should Do Soon

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Fix Sunset Orange color to match Style Guide | `pending` | Should be #FF6B35, currently #D84315 | 2026-01-01 |
| Remove extra colors not in Style Guide | `pending` | Simplify to 8 official colors | 2026-01-01 |
| Implement AVFoundation QR scanner | `pending` | Currently placeholder | 2026-01-01 |
| Add SwiftProtobuf for full protobuf parsing | `pending` | Current implementation is simplified | 2026-01-01 |

---

## 🟡 Priority 3: Medium / Nice to Have

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Camp-to-camp location sharing via Meshtastic | `pending` | Send camp layout/location to friends | 2026-01-01 |
| Simplify navigation (reduce to 4 tabs) | `pending` | UX audit recommendation | 2026-01-01 |
| Reduce Quick Actions from 9 to 6 tiles | `done` | Reduced from 9 to 8 | 2026-01-01 |
| Add "Next Action" card to Home | `pending` | Personalized prompt for users | 2026-01-01 |
| Combine Playa Map + Camp Map | `done` | Consolidated into Camp Layout | 2026-01-01 |
| Implement calendar view for events | `pending` | Currently placeholder | 2026-01-01 |
| CloudKit sync for cross-device | `pending` | Future enhancement | 2026-01-01 |

---

## 🟢 Priority 4: Low / Backlog

| Task | Status | Notes | Added |
|------|--------|-------|-------|
| Add unit tests for managers | `pending` | Improve code quality | 2026-01-01 |
| Add UI tests for critical flows | `pending` | Improve reliability | 2026-01-01 |
| Localization support | `pending` | Future internationalization | 2026-01-01 |
| Dark/Light mode toggle | `pending` | Currently dark only | 2026-01-01 |

---

## ✅ Recently Completed

| Task | Completed | Notes |
|------|-----------|-------|
| Add search to Camp Layout with highlight/gray-out | 2026-01-01 | Search by name/person, matches glow |
| Consolidate Camp Map + Layout into one feature | 2026-01-01 | Single "Camp Layout" in Camp tab |
| Remove upload map functionality | 2026-01-01 | Clean playa sand background instead |
| Create TODO.md task tracking framework | 2026-01-01 | Priority-based, session notes |
| Implement full Meshtastic BLE protocol | 2026-01-01 | MeshtasticProtocol.swift + MeshtasticManager.swift |
| Create T1000-E setup documentation | 2026-01-01 | docs/T1000-E_SETUP_GUIDE.md |
| Make safety check-in opt-in (off by default) | 2026-01-01 | Respects burner autonomy |
| Add 10 Principles to Knowledge Base | 2026-01-01 | Pinned article |
| Update leaderboard with names (accountability) | 2026-01-01 | No anonymity for performance |
| Add BM-compliant camp layout presets | 2026-01-01 | 50' increments, fire lanes |

---

## 📋 Session Notes

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

*Last updated: 2026-01-01*
