# Robot Heart iOS App - Project Plan

**Date**: 2026-01-04  
**Status**: Active Development

---

## 1. Project Overview

This document outlines the current state, recent accomplishments, and future roadmap for the Robot Heart iOS application. The project's primary goal is to create a **disaster-ready, resilient communication platform** for the Robot Heart camp and the wider Burning Man community, with year-round applicability.

### Core Mission

- **Offline-First**: The app must be 100% functional without internet or cellular service.
- **Opportunistic Connectivity**: Automatically leverage internet (WiFi, Starlink, Cellular) when available to enhance communication.
- **Resilience**: No single point of failure. The mesh network must survive even if cloud services are down.
- **Community-Focused**: Foster connection, safety, and social capital within the camp.

### Current Architecture

The app is built on a **4-Layer Network Architecture**:

| Layer | Technology | Role |
|:------|:-----------|:-----|
| **1. Cloud** | HTTPS + Digital Ocean S3 | Fast, global communication (when online) |
| **2. Meshtastic** | LoRa Mesh | Long-range, offline communication |
| **3. BLE Mesh** | Bluetooth LE | Short-range presence and data |
| **4. Local Storage** | Core Data / SQLite | Offline cache and message queue |

---

## 2. Current State Analysis (as of 2026-01-04)

The project has undergone significant architectural refactoring to establish a robust and scalable foundation.

### Repository Statistics

| Metric | Value |
|:---|:---|
| **Total Commits** | 76 |
| **Total Swift Files** | 84 |
| **Total Lines of Swift Code** | ~38,557 |
| **Total Documentation Files** | 13 |

### Key Architectural Components

- **`AppEnvironment`**: A centralized dependency injection container that manages all services.
- **`NetworkOrchestrator`**: Intelligently routes messages across the 4 network layers.
- **`CloudSyncService`**: Manages opportunistic cloud sync with Digital Ocean S3.
- **`KeychainService`**: Securely stores sensitive credentials (S3 keys).
- **`AWSV4Signer`**: Provides production-grade authentication for all S3 requests.

### Documentation

The project is well-documented, with 13 detailed guides in the `docs/` directory covering architecture, protocols, security, and setup.

---

## 3. Recently Completed Milestones (Phase 1 & 2)

The last two major work cycles focused on addressing technical debt and implementing a resilient networking strategy.

### Milestone 1: Architectural Refactoring (Phase 1)

- **Commit**: `fb443b2`
- **Objective**: Simplify the architecture and resolve network conflicts.
- **Key Deliverables**:
    - Created `AppEnvironment` to replace massive dependency injection.
    - Created `NetworkOrchestrator` to manage Meshtastic and BLE coexistence.
    - Fixed style guide inconsistencies.
    - Created `REFACTORING_GUIDE.md`.

### Milestone 2: 4-Layer Network & S3 Integration (Phase 2)

- **Commits**: `442c247`, `5be31d5`
- **Objective**: Integrate internet connectivity as an opportunistic layer.
- **Key Deliverables**:
    - Designed and documented the **4-Layer Network Architecture**.
    - Implemented `CloudSyncService` for Digital Ocean S3.
    - Implemented **automatic gateway node promotion** for devices with internet.
    - Implemented **`KeychainService`** for secure credential storage.
    - Implemented **`AWSV4Signer`** for production-grade S3 authentication.
    - Created `S3_INTEGRATION_GUIDE.md` and `S3SettingsView.swift`.
    - Updated `NetworkOrchestrator` to handle all 4 layers.

### Milestone 3: Resilient Communications Research

- **Commit**: `a6d77b3`
- **Objective**: Ground the project's strategy in real-world disaster response use cases.
- **Key Deliverables**:
    - Created `RESILIENT_COMMS_PLAN.md`.
    - Synthesized research from Burning Man, Hurricane Helene/Ian responses, and the Hackaday community.
    - Validated the satellite/Starlink-first approach for gateway nodes.

---

## 4. Project Roadmap: Next Steps

This roadmap is based on the `TODO.md` file and logical project progression.

### Phase 3: Field Testing & Service Decomposition (Immediate Priority)

**Objective**: Validate the current architecture with real hardware and continue to address technical debt.

| Task | Priority | Status | Notes |
|:---|:---|:---|:---|
| **Test with T1000-E Device** | 🔴 P1 | `pending` | **Highest priority**. Validate LoRa range, battery, and gateway functionality. |
| **Configure Digital Ocean S3** | 🔴 P1 | `pending` | Create bucket, generate keys, and configure CORS to test end-to-end cloud sync. |
| **Complete Service Decomposition** | 🟠 P2 | `pending` | Break down `MeshtasticManager` into focused services (Nodes, Messages, Location, Protocol). |
| **Add SwiftProtobuf Library** | 🟠 P2 | `pending` | Implement full protobuf parsing instead of the current simplified version. |
| **Implement QR Code Scanner** | 🟠 P2 | `pending` | Replace placeholder with `AVFoundation` scanner for adding contacts/nodes. |
| **Refine UI Colors** | 🟠 P2 | `pending` | Remove extra colors from the theme to align with the 8 official Style Guide colors. |

### Phase 4: UI/UX Refinement & Core Features (Short-Term)

**Objective**: Improve usability and complete core feature set based on user feedback and the established roadmap.

| Task | Priority | Status | Notes |
|:---|:---|:---|:---|
| **Simplify Navigation** | 🟡 P3 | `pending` | Reduce the main navigation to 4 primary tabs (Home, Community, Map, Me). |
| **Implement Calendar View** | 🟡 P3 | `pending` | Create a proper calendar view for camp events and shifts. |
| **Add "Next Action" Card** | 🟡 P3 | `pending` | Add a personalized card to the Home screen to guide user engagement. |
| **Camp-to-Camp Sharing** | 🟡 P3 | `pending` | Allow users to share their camp's location and layout with friends in other camps. |

### Phase 5: Quality & Scalability (Medium-Term)

**Objective**: Harden the application for public release and long-term maintenance.

| Task | Priority | Status | Notes |
|:---|:---|:---|:---|
| **Add Unit Tests** | 🟢 P4 | `pending` | Add test coverage for all services, especially `NetworkOrchestrator` and `CloudSyncService`. |
| **Add UI Tests** | 🟢 P4 | `pending` | Create UI tests for critical user flows like onboarding, sending messages, and SOS. |
| **CloudKit Sync** | 🟡 P3 | `pending` | Explore CloudKit for syncing user settings and non-mesh data across devices. |
| **Localization Support** | 🟢 P4 | `pending` | Prepare the app for internationalization and translation. |

---

## 5. Key Project Documents

All documentation is located in the `/docs` directory of the repository.

- **`PROJECT_PLAN.md`**: This document.
- **`TODO.md`**: The granular, living task list for developers.
- **`RESILIENT_COMMS_PLAN.md`**: Research and strategy for disaster-ready communication.
- **`NETWORK_LAYERS.md`**: The complete 4-layer network architecture.
- **`S3_INTEGRATION_GUIDE.md`**: Guide for configuring Digital Ocean S3 with Keychain and CORS.
- **`REFACTORING_GUIDE.md`**: Guide for migrating from the old architecture.
- **`ARCHITECTURE.md`**: Original high-level design principles.
- **`T1000-E_SETUP_GUIDE.md`**: Guide for setting up the recommended hardware.
- **`PROTOCOL.md`**: Details on the communication protocols used.
- **`SECURITY.md`**: Overview of security considerations.
- **`SCALE_ANALYSIS.md`**: Analysis of the network's scalability.
- **`SOCIAL_CAPITAL_ECONOMY.md`**: Concept for the in-app social economy.
- **`TOKEN_ECONOMY.md`**: Details on the token/` (if applicable).
