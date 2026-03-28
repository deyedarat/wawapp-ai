# Known Issues & Constraints - wawapp-ai

## Firebase Auth
- **Rate Limiting**: `too-many-requests` error is common during heavy debug sessions.
- **Solution**: Use Test Phone Numbers in Firebase Console for uninterrupted development.

## PIN Security
- **Strength Validation**: PINs like `1234`, `0000`, `1111` are rejected by current logic.
- **User Confusion**: Error messages were English, now partially localized. Still need to ensure users understand WHY a PIN is rejected.

## Environment Persistence
- SHA-1 keys must be registered for every new development environment/machine for OTP and Maps to function correctly.
- Currently, Samsung A14 device is being used for live testing.
