# Faster Demo

**DEMO VERSION — NOT FOR PRODUCTION USE**

## Overview

This is a demonstration/training build of the Faster application. All business logic,
database connections, payment processing, and sensitive functionality have been
replaced with mock stubs and placeholder implementations.

## Purpose

- Product demonstrations for potential clients/stakeholders
- Training environment for new team members
- UI/UX review and design iteration
- Workflow simulation without real data or transactions

## What's Included

| Component | Status |
|-----------|--------|
| UI Screens & Navigation | ✅ Full replica |
| Theme & Styling | ✅ Authentic colors/fonts |
| Mock Data Responses | ✅ Realistic fake data |
| Workflow Diagrams | ✅ Generic process flows |
| Placeholder Schema | ✅ Fake tables & fields |

## What's Excluded / Restricted

| Component | Status | Reason |
|-----------|--------|--------|
| Real Supabase Connection | ❌ Replaced with mock | Security |
| Payment Processing | ❌ LABELED RESTRICTED | Sensitive logic |
| License & Policy Modules | ❌ REMOVED | Proprietary |
| Server Endpoints | ❌ Stubbed | No real logic |
| Security/Honeypot Systems | ❌ Stubbed | No real logic |
| Firebase Notifications | ❌ Stubbed | No real logic |

## Build Instructions

### Prerequisites

- Flutter SDK ^3.8.0
- Dart SDK ^3.8.0

### Build Demo APK

```bash
cd demo\scripts
.\build_demo.bat
```

Or manually:

```bash
flutter build apk --debug --dart-define=FLUTTER_APP_FLAVOR=demo
```

## Architecture (Demo)

```
┌─────────────────────────────────────────┐
│           UI Layer (Authentic)          │
│  All screens, widgets, navigation intact │
├─────────────────────────────────────────┤
│        Mock Service Layer (New)         │
│  MockSupabaseService                    │
│  MockAuthRepository                     │
│  MockResponses                          │
│  MockData                               │
├─────────────────────────────────────────┤
│         Stub Layer (Restricted)         │
│  Paymob → 🚫 RESTRICTED STUB           │
│  License → 🚫 RESTRICTED STUB           │
│  Policies → 🚫 RESTRICTED STUB          │
└─────────────────────────────────────────┘
```

## File Structure (Demo-specific)

```
lib/
├── core/
│   ├── mock/              ← NEW: Mock service implementations
│   │   ├── mock_supabase_service.dart
│   │   ├── mock_auth_repository.dart
│   │   ├── mock_responses.dart
│   │   └── mock_data.dart
│   └── services/          ← Modified: Some services stubbed
├── main_demo.dart         ← NEW: Demo entry point
└── demo_app.dart          ← NEW: Demo app wrapper
demo/
├── README.md              ← THIS FILE
├── SCHEMA.md              ← Placeholder database schema
├── diagrams/
│   └── workflows.md       ← Process flow diagrams
└── scripts/
    └── build_demo.bat     ← Demo build script
```

## Important Notes

⚠️ **This is a DEMO only.** No real transactions, data persistence,
or business logic is executed. All responses are simulated.

🚫 **Do NOT** use this build in production environments.
🚫 **Do NOT** connect this build to real Supabase or payment endpoints.
🚫 **Do NOT** reverse-engineer for production repurposing.

---

**Faster Demo** © 2024 — Training & Demonstration Purpose Only
