# Implementation Plan — Auth by Phone + 4-Digit PIN

## Goal
Enable sign-in/sign-up using **phone number** + **4-digit PIN**, with minimal UI for **client** و **driver** apps، وتخزين آمن للـ PIN (salted+hashed).

## Scope (Phase 1)
- ✅ Screens: Phone → Verify Code (OTP) → Create/Enter PIN → Home
- ✅ Persist user profile in Firestore
- ✅ Store PIN as hash (PBKDF2/SHA256) + salt
- ✅ Session restore on app start
- ✅ Basic analytics + error logging

Out of scope (Phase 1): lockout policy, biometric unlock, PIN change flow (مرحلة لاحقة).

## Data Model (Firestore)
- **collections**:
  - `users/{uid}`  
    ```json
    {
      "phone": "+222...",
      "role": "driver|client",
      "pin": {
        "alg": "pbkdf2-sha256",
        "salt": "<base64>",
        "hash": "<base64>",
        "iterations": 310000
      },
      "created_at": <serverTimestamp>,
      "updated_at": <serverTimestamp>
    }
    ```
- Security Rules (ملخص):  
  - `allow read, write: if request.auth.uid == resource.id;`  
  - منع الكتابة المباشرة لحقل `pin.*` من العميل (يتم عبر Cloud Function فقط) (إن أضفنا CF).

## Flows
1) **Sign-in (first time)**:  
   Phone → Firebase OTP → on success → **Create PIN** → Hash+Store → Home
2) **Sign-in (returning)**:  
   Phone (prefilled if cached) → **Enter PIN** → Verify hash → Home
3) **Sign-out**: clear local session, keep Firestore profile

## UI Tasks
- ✅ Client: `/features/auth/phone/` (PhoneScreen, OtpScreen, CreatePinScreen, EnterPinScreen)
- ✅ Driver: نفس المسارات داخل تطبيق السائق
- ✅ Shared `PinPad` widget (0-9, delete, masked dots)
- ✅ Error states (invalid PIN, OTP timeout, network)

## Services
- ✅ `AuthService`: phone auth (OTP), get/set currentUser
- ✅ `PinService`: local cache for phone, hash+verify via `crypto` (PBKDF2)
- ✅ `UserRepo`: CRUD Firestore `users/{uid}`, server timestamps
- ⏳ Optional: `Cloud Function setPin(uid, hash,salt,iter)` لتقييد الكتابة

## Tech Notes
- Hash = PBKDF2(SHA256, iterations=310k, salt=16 bytes), output 32 bytes (base64).
- Do **not** store raw PIN.
- Persist minimal local state: `{ phone, uid }` فقط.

## Testing
- ⏳ Unit: PinService hash/verify (happy/edge cases)
- ⏳ Widget: PinPad input + masking
- ⏳ Integration: full sign-in flow (mock OTP)
- ⏳ Manual checklist (Android): airplane mode, bad PIN, OTP resend

## Telemetry
- ✅ log: `auth_start`, `otp_verified`, `pin_created`, `pin_verified`, `auth_fail`
- ✅ attach: build, role, device

## Rollback
- احتفظنا بنسخ `.bak` للخطة + يمكن تعطيل flow الـ PIN بإظهار OTP-only (toggle في Remote Config).

## Milestones
- ✅ M1: شاشات Phone/OTP
- ✅ M2: PinPad + Create/Enter + Hash
- ✅ M3: Firestore profile + session restore
- ⏳ M4: اختبارات + تتبّع

## Status
**Implementation**: ✅ Complete  
**Testing**: ⏳ In Progress (Phase 5)
