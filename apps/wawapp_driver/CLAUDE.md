# WawApp Driver — CLAUDE.md  
### Unified Driver-Side Coding Rules (2025)

This document defines how Claude Code must behave when modifying or reasoning about  
**apps/wawapp_driver/** only.

---

## 1. Scope of Authority
Claude may ONLY read/edit files inside:

- apps/wawapp_driver/lib/**
- apps/wawapp_driver/pubspec.yaml
- apps/wawapp_driver/android/**
- apps/wawapp_driver/ios/**
- apps/wawapp_driver/assets/**
- packages/auth_shared/**
- .claude/agents/**
- tools/** (read-only)

❌ Prohibited:
- Modifying client app
- Changing order/pricing logic (read-only)
- Editing backend/Firebase rules

---

## 2. Primary Agents Used in Driver App
Claude must delegate automatically to:

- **wawapp-driver-agent**
- **wawapp-geo-agent**
- **wawapp-fcm-agent**
- **wawapp-security-agent**
- **wawapp-auth-agent** (for login/PIN flows)

---

## 3. Architecture Requirements (Driver)
- UI = Flutter + Riverpod ONLY  
- Features live under `lib/features/...`

Driver-specific rules:
- Nearby Orders logic stays in:
  - `features/home`
  - `features/map`
- Driver status must sync with Firestore
- Earnings logic is read-only unless approved

---

## 4. Allowed Commands
- `flutter analyze`
- `flutter format .`
- `.\spec.ps1 driver:*`
- `.\spec.ps1 env:verify`
- `.\spec.ps1 fcm:verify`

---

## 5. Forbidden Actions
- No navigation changes without approval
- No Firestore index changes
- No API key insertion
- No placeholder values
- No silent refactors

---

## 6. Safety & Logging
Driver-specific logging rules:
- Log: location updates
- Log: nearby orders queries
- Log: FCM token events
- Never log: phone numbers, PINs, auth tokens

---

## 7. Before Any Edit
Claude must:

1. Activate Plan Mode
2. Load:
   - this file
   - root CLAUDE.md
   - relevant driver agents
3. Propose:
   - files to touch
   - steps
   - expected outcome

Wait for approval.

---

## 8. After Any Edit
- run analyze  
- format  
- commit with message:  
```
chore(driver): <description>
```
- update CHANGES.md

---

## 9. Emergency Stop
If anything affects:
- auth flow
- map flow
- order acceptance
Claude must STOP and request clarification.

