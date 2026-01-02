# Robot Heart iOS - Production Roadmap

## Vision
An **offline social network of reliable people** - where contributions build trust that carries across events, year-round.

---

## Current State (v0.1 - Alpha)

### ✅ What's Built
- Offline-first architecture (BLE mesh + Meshtastic LoRa + CloudKit sync)
- Shift management with points system
- Task system with priorities
- Camp layout planner (BM-compliant)
- Social capital model (trust levels)
- Multi-camp protocol
- Global search with privacy controls
- Safety features (SOS, check-ins, announcements)

### 🔴 Critical Gaps for Mass Adoption
1. No real onboarding flow
2. No TestFlight/App Store presence
3. Mock data everywhere - needs real persistence
4. BLE mesh not tested at scale
5. No push notifications
6. No profile photos (camera integration)
7. QR code scanner is placeholder

---

## Phase 1: Core Polish (4-6 weeks)
*Goal: Make it actually usable for a small group*

### 1.1 Onboarding Flow
- [ ] Welcome screens explaining the 10 Principles
- [ ] Profile creation (playa name, photo, home city)
- [ ] Camp join/create flow
- [ ] Permission requests (Bluetooth, Location, Notifications)
- [ ] Tutorial overlay for first-time users

### 1.2 Real Data Persistence
- [ ] Migrate all UserDefaults to Core Data
- [ ] Implement proper CloudKit sync
- [ ] Add data export/import for backup
- [ ] Handle app reinstalls gracefully

### 1.3 Camera & QR Integration
- [ ] Implement AVFoundation camera for QR scanning
- [ ] Profile photo capture/selection
- [ ] QR code generation for profile sharing
- [ ] Contact exchange via QR scan

### 1.4 Push Notifications
- [ ] Local notifications for shift reminders
- [ ] Notification categories (shifts, tasks, emergencies)
- [ ] Notification preferences in settings
- [ ] Background refresh for mesh sync

### 1.5 UI/UX Polish
- [ ] Loading states and skeletons
- [ ] Empty states with helpful CTAs
- [ ] Error handling with user-friendly messages
- [ ] Haptic feedback on key actions
- [ ] Accessibility audit (VoiceOver, Dynamic Type)

---

## Phase 2: Social Capital System (4 weeks)
*Goal: Make reputation portable and meaningful*

### 2.1 Social Capital Manager
- [ ] Create `SocialCapitalManager` service
- [ ] Persist lifetime stats across app reinstalls
- [ ] Sync social capital via CloudKit
- [ ] Calculate trust levels dynamically

### 2.2 Event History
- [ ] Track participation by event (BM 2025, regionals, etc.)
- [ ] Show contribution history on profile
- [ ] "Veteran" badges for multi-year participants
- [ ] Event-specific leaderboards

### 2.3 Portable Identity
- [ ] Export social capital as signed credential
- [ ] Import credentials from other camps
- [ ] Verify credentials cryptographically
- [ ] "Vouch" system - trusted members can vouch for newcomers

### 2.4 Trust Visualization
- [ ] Trust badges on profiles (⭐ Superstar, etc.)
- [ ] Reliability graph over time
- [ ] "Network" view showing trusted connections
- [ ] Recommendations: "People like you trust..."

---

## Phase 3: Mesh Network Hardening (6 weeks)
*Goal: Actually work at Burning Man scale*

### 3.1 BLE Mesh Testing
- [ ] Test with 10+ devices in proximity
- [ ] Measure message delivery rates
- [ ] Optimize relay algorithm
- [ ] Handle device sleep/wake cycles

### 3.2 Meshtastic Integration
- [ ] Real device pairing (SenseCAP T1000-E)
- [ ] Channel configuration UI
- [ ] Message routing between BLE and LoRa
- [ ] Range testing in open desert conditions

### 3.3 Gateway Node Optimization
- [ ] Auto-detect Starlink connectivity
- [ ] Efficient CloudKit batch sync
- [ ] Conflict resolution for offline edits
- [ ] Bandwidth-aware sync (don't hog Starlink)

### 3.4 Message Reliability
- [ ] Delivery confirmations UI
- [ ] Retry queue visualization
- [ ] "Message pending" indicators
- [ ] Offline queue management

---

## Phase 4: Camp Admin Tools (4 weeks)
*Goal: Make it easy for camp leads to manage*

### 4.1 Admin Dashboard
- [ ] Camp stats overview (participation, reliability)
- [ ] Bulk shift creation
- [ ] Member management (invite, remove, roles)
- [ ] Announcement composer with scheduling

### 4.2 Shift Templates
- [ ] Save shift patterns as templates
- [ ] Clone shifts from previous years
- [ ] Auto-generate shift blocks from templates
- [ ] Shift swap marketplace

### 4.3 Reporting
- [ ] Export participation data (CSV)
- [ ] No-show reports for accountability
- [ ] Points summary by member
- [ ] Event retrospective generator

### 4.4 Multi-Camp Federation
- [ ] Camp-to-camp resource sharing
- [ ] Cross-camp event promotion
- [ ] Shared emergency protocols
- [ ] Inter-camp messaging for leads

---

## Phase 5: App Store Launch (4 weeks)
*Goal: Public availability*

### 5.1 TestFlight Beta
- [ ] Internal testing (core team)
- [ ] External beta (50-100 camp members)
- [ ] Crash reporting (Sentry/Crashlytics)
- [ ] Analytics (privacy-respecting)

### 5.2 App Store Submission
- [ ] App Store screenshots
- [ ] App preview video
- [ ] Privacy policy
- [ ] Terms of service
- [ ] App Store description & keywords

### 5.3 Marketing Site
- [ ] Landing page (robotheart.app?)
- [ ] Feature overview
- [ ] Privacy explanation
- [ ] Download links

### 5.4 Documentation
- [ ] User guide
- [ ] Camp lead guide
- [ ] FAQ
- [ ] Troubleshooting

---

## Phase 6: Beyond Burning Man (Ongoing)
*Goal: Year-round community platform*

### 6.1 Off-Season Events
- [ ] Regional burn support
- [ ] Camp trips and meetups
- [ ] Build weeks
- [ ] Fundraisers

### 6.2 Community Features
- [ ] Discussion threads (async)
- [ ] Photo sharing (post-event)
- [ ] Skill directory ("I can weld")
- [ ] Equipment lending

### 6.3 Open Source
- [ ] Clean up codebase for public
- [ ] Contribution guidelines
- [ ] Plugin architecture for other camps
- [ ] White-label option

---

## Technical Debt to Address

### High Priority
- [ ] Remove all mock data generators
- [ ] Implement proper error handling throughout
- [ ] Add unit tests for managers
- [ ] Add UI tests for critical flows

### Medium Priority
- [ ] Refactor large view files (HomeView, ShiftsView)
- [ ] Extract reusable components
- [ ] Standardize API patterns
- [ ] Document all public interfaces

### Low Priority
- [ ] Performance profiling
- [ ] Memory leak audit
- [ ] Reduce app binary size
- [ ] Localization preparation

---

## Success Metrics

### Alpha (Now → BM 2026)
- [ ] 50+ camp members using daily
- [ ] 90%+ shift completion rate
- [ ] <5% crash rate
- [ ] Mesh works with 20+ devices

### Beta (BM 2026)
- [ ] 200+ active users during event
- [ ] Messages delivered within 30s on mesh
- [ ] Social capital tracked for all participants
- [ ] Zero critical bugs during event

### v1.0 (Post-BM 2026)
- [ ] App Store launch
- [ ] 3+ camps using the platform
- [ ] Year-round engagement
- [ ] Community contributions

---

## Immediate Next Steps

1. **This Week**
   - [ ] Implement real onboarding flow
   - [ ] Replace mock data with Core Data persistence
   - [ ] Add camera/QR functionality

2. **This Month**
   - [ ] TestFlight internal build
   - [ ] Social Capital Manager implementation
   - [ ] BLE mesh testing with 5+ devices

3. **Before BM 2026**
   - [ ] Full beta with camp members
   - [ ] Meshtastic device testing
   - [ ] Admin tools for camp leads

---

## Resources Needed

### Development
- iOS developer time (you + AI pair programming)
- Test devices (multiple iPhones, Meshtastic radios)
- Apple Developer account ($99/year)

### Design
- App icon refinement
- Marketing screenshots
- Onboarding illustrations

### Infrastructure
- CloudKit (included with Apple Developer)
- Domain for marketing site
- TestFlight distribution

---

*Last updated: January 2026*
