# Technology Stack - wawapp-ai

## Frontend
- **Framework**: Flutter (Latest stable).
- **State Management**: flutter_riverpod, flutter_hooks.
- **Navigation**: GoRouter (integrated with Riverpod for auth-based routing).
- **Maps**: Google Maps Flutter for real-time tracking.

## Backend
- **Platform**: Firebase.
- **Authentication**: Firebase Auth (Phone), Custom PIN system via Cloud Functions.
- **Database**: Cloud Firestore.
- **Logic**: Cloud Functions (TypeScript) with Firebase Admin SDK.
- **Messaging**: Firebase Cloud Messaging (FCM) for push notifications.

## Infrastructure
- **CI/CD**: Codemagic/GitHub Actions.
- **Analytics**: Firebase Analytics & Crashlytics for reliability monitoring.
