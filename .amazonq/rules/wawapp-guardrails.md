# WawApp Project Guardrails — Amazon Q Supervisor Rules

## 1. Command Execution Policy
- Never suggest running Flutter commands directly (`flutter clean`, `flutter pub get`, `flutter run`).
- All execution MUST go through the project PowerShell scripts:
  - `.\spec.ps1 env:doctor`
  - `.\spec.ps1 env:verify`
  - `.\spec.ps1 fcm:verify`
  - `.\spec.ps1 flutter:run-client`
  - `.\spec.ps1 flutter:run-driver`

## 2. Security & API Keys
- Never show or use google-services.json content.
- Never commit or include API keys, FCM keys, or Firebase credentials in code.
- If a key appears in code, warn immediately and suggest adding it to `.gitignore`.

## 3. Flutter App Rules
- Apply minimal-diff changes only.
- Ask for missing context instead of guessing.
- Keep Riverpod architecture intact.
- Do NOT rewrite entire files unless explicitly requested.

## 4. Authentication Rules
- Treat OTP + PIN flows as production-critical.
- Avoid modifying `otpStage`, `otpFlowActive`, or Firestore user records without confirming the logic.
- Prefer adding logs instead of removing logic.

## 5. Firestore / Security Rules
- Never weaken Firestore rules just to bypass errors.
- Warn before suggesting any rule that broadens read/write access.

## 6. Navigation / Routing
- Before suggesting fixes, validate:
  - AuthGate
  - PhonePinAuth
  - OTP screens
  - Routing providers
