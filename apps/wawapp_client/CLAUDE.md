# WawApp Client — CLAUDE.md  
### Unified Client-Side Coding Rules (2025)

This document defines how Claude Code must behave when modifying or reasoning about  
**apps/wawapp_client/** only.

---

## 1. Scope of Authority
Claude may ONLY read/edit files inside:

- apps/wawapp_client/lib/**
- apps/wawapp_client/pubspec.yaml
- apps/wawapp_client/android/**
- apps/wawapp_client/ios/**
- apps/wawapp_client/assets/**
- packages/auth_shared/**
- .claude/agents/**
- tools/** (read-only, for commands)

❌ Prohibited:
- Touching driver app code
- Touching backend Firestore structure
- Touching migration files
- Touching env variables without explicit request

---

## 2. Primary Agents Used in Client App
Claude must delegate automatically to:

- **wawapp-client-agent**
- **wawapp-geo-agent**
- **wawapp-pricing-agent**
- **wawapp-fcm-agent**
- **wawapp-auth-agent**
- **wawapp-security-agent** (read-only diagnostics)

Delegation syntax:
```
@agent wawapp-client-agent
```

---

## 3. Architecture Requirements (Client)
- UI = Flutter + Riverpod ONLY  
- No Bloc, Cubit, GetX  
- Features live under `lib/features/...`  
- Each feature MUST have:
  - controller
  - service (or repo)
  - widgets
  - models

Client-specific constraints:
- Navigation uses GoRouter
- Geolocation through geo agent only
- Pricing must call pricing agent logic only

---

## 4. Allowed Commands
- `flutter analyze`
- `flutter format .`
- `.\spec.ps1 client:*`
- `.\spec.ps1 env:verify`
- `.\spec.ps1 fcm:verify`

---

## 5. Forbidden Actions
- Adding any secret keys
- Adding placeholders
- Silent refactors
- Changing Firestore rules
- Modifying shared logic without permission

---

## 6. Safety & Logging
- Add logs only in business logic, not UI
- Follow the structured logger format:
  - INFO: user action
  - WARN: unexpected but handled
  - ERROR: catch exceptions only

---

## 7. Before Any Edit
Claude must:

1. Enter **Plan Mode**
2. Read:
   - this file
   - root CLAUDE.md
   - relevant agent files
3. Produce:
   - What will be changed
   - Why
   - Where
4. Wait for human approval

---

## 8. After Any Edit
Claude must:
- run analyze
- run format
- generate commit message (English, conventional commits)
- generate CHANGES.md update

---

## 9. Emergency Stop
If any client-side requirement is unclear:
Claude must STOP and request clarification immediately.

