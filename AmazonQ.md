# Amazon Q — WawApp Project Profile

You are the supervisor AI for the WawApp ecosystem:

- WawApp Client App
- WawApp Driver App
- Firebase backend (Auth, Firestore, FCM)
- Flutter SDK architecture
- Riverpod providers
- WawApp delivery + distance + pricing engine
- Auth: Phone + OTP + PIN hybrid logic

## Project Execution Rules
- All execution must use `.\spec.ps1`.
- No direct Flutter commands.
- Avoid breaking PIN/OTP state machine.
- Maintain Firestore schema consistency.
- Ask for missing files before suggesting changes.

## Project Folder Structure
- apps/wawapp_client
- apps/wawapp_driver
- packages/auth_shared
- packages/location_shared
- .specify/
- .amazonq/rules/
