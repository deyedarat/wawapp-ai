# Implementation Plan: Phone + PIN Authentication

**Branch**: `feat/auth-phone-pin` | **Date**: 2024-12-19 | **Spec**: [spec.md](./spec.md)

## Summary

Implement phone number authentication with PIN-based login for WawApp client app. Users register with phone + OTP, create a PIN, and use phone + PIN for subsequent logins. Includes PIN reset via OTP.

## Technical Context

**Language/Version**: Dart 3.5+ / Flutter 3.35.5  
**Primary Dependencies**: firebase_auth, flutter_secure_storage, riverpod, go_router  
**Storage**: Firebase Auth + Secure Storage (PIN), Firestore (user profiles)  
**Testing**: flutter_test, mockito  
**Target Platform**: Android/iOS mobile  
**Project Type**: Mobile (Flutter)  
**Performance Goals**: <5s login, <2min registration  
**Constraints**: Secure PIN storage, offline-capable PIN verification  
**Scale/Scope**: Multi-language (AR/FR/EN), Material 3 UI

## Constitution Check

✅ Flutter 3.35.x - Compliant  
✅ Firebase services - Compliant  
✅ Riverpod state management - Compliant  
✅ Feature-based architecture - Compliant  
✅ Security standards - Compliant (encrypted storage)  
✅ i18n support - Compliant (AR/FR/EN)

## Project Structure

### Documentation (this feature)

```text
specs/auth-phone-pin/
├── spec.md              # Feature specification
├── plan.md              # This file
├── data-model.md        # Data structures
├── quickstart.md        # Setup guide
├── contracts/           # API contracts
└── tasks.md             # Implementation tasks
```

### Source Code

```text
apps/wawapp_client/lib/features/auth/
├── data/
│   ├── models/
│   │   └── user_model.dart
│   └── repositories/
│       └── firebase_auth_repository.dart
├── domain/
│   ├── entities/
│   │   └── user_entity.dart
│   └── repositories/
│       └── auth_repository.dart
├── presentation/
│   ├── bloc/
│   │   ├── auth_bloc.dart
│   │   ├── auth_event.dart
│   │   └── auth_state.dart
│   ├── screens/
│   │   ├── welcome_screen.dart
│   │   ├── phone_input_screen.dart
│   │   ├── otp_verification_screen.dart
│   │   ├── pin_setup_screen.dart
│   │   ├── login_screen.dart
│   │   └── forgot_pin_screen.dart
│   └── widgets/
│       ├── phone_input_field.dart
│       ├── otp_input_field.dart
│       └── pin_input_field.dart
└── services/
    ├── phone_auth_service.dart
    ├── pin_service.dart
    └── auth_logger.dart
```

**Structure Decision**: Feature-based architecture following WawApp constitution. Clean architecture with data/domain/presentation layers.

## Complexity Tracking

No constitution violations. Implementation follows established patterns.
