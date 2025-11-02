# Feature Specification: Phone Number + PIN Authentication

**Feature Branch**: `001-phone-pin-auth`  
**Created**: 2025-01-28  
**Status**: Draft  
**Input**: User description: "Phone number + 4-digit PIN authentication for both Client and Driver apps"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - New User Registration (Priority: P1)

A new user (client or driver) downloads the app and needs to create an account using their phone number and a secure 4-digit PIN.

**Why this priority**: Core foundation - no user can access the app without registration. This is the entry point for all users.

**Independent Test**: Can be fully tested by completing phone verification and PIN setup, delivering a registered user account that can be used for login.

**Acceptance Scenarios**:

1. **Given** a new user opens the app, **When** they enter a valid phone number and request verification, **Then** they receive an OTP via SMS within 30 seconds
2. **Given** user receives OTP, **When** they enter the correct code, **Then** they are prompted to create a 4-digit PIN
3. **Given** user is setting up PIN, **When** they enter and confirm a 4-digit PIN, **Then** their account is created and they are logged in
4. **Given** user enters invalid OTP, **When** they submit it, **Then** they see an error message and can request a new OTP
5. **Given** user sets up PIN, **When** they enter non-matching confirmation PIN, **Then** they see an error and must re-enter both PINs

---

### User Story 2 - Returning User Login (Priority: P1)

An existing user opens the app and logs in using their phone number and PIN to access their account.

**Why this priority**: Essential for user retention - users must be able to access their existing accounts.

**Independent Test**: Can be fully tested with a pre-registered account by entering phone number and PIN, delivering authenticated access to the app.

**Acceptance Scenarios**:

1. **Given** a registered user opens the app, **When** they enter their phone number and correct PIN, **Then** they are logged into their account
2. **Given** user enters wrong PIN, **When** they submit it, **Then** they see an error message and can retry
3. **Given** user enters wrong PIN 5 times, **When** they attempt the 6th try, **Then** they are locked out with exponential backoff timing
4. **Given** user is locked out, **When** the lockout period expires, **Then** they can attempt login again

---

### User Story 3 - PIN Recovery (Priority: P2)

A user who forgot their PIN can recover access to their account by re-verifying their phone number.

**Why this priority**: Important for user retention but not blocking core functionality - users can still register new accounts if needed.

**Independent Test**: Can be fully tested by using "Forgot PIN" flow with phone re-verification, delivering restored account access.

**Acceptance Scenarios**:

1. **Given** user forgot their PIN, **When** they tap "Forgot PIN" and enter their phone number, **Then** they receive a new OTP
2. **Given** user completes phone re-verification, **When** they enter the correct OTP, **Then** they can set a new 4-digit PIN
3. **Given** user sets new PIN after recovery, **When** they complete the process, **Then** they are logged into their account

---

### User Story 4 - Device Re-linking (Priority: P3)

A user with an existing account installs the app on a new device and needs to link their account by re-verifying their phone number.

**Why this priority**: Enhances user experience but not critical for core functionality - users can still use primary device.

**Independent Test**: Can be fully tested by installing app on new device and completing phone re-verification, delivering account access on the new device.

**Acceptance Scenarios**:

1. **Given** user installs app on new device, **When** they enter their registered phone number, **Then** they can request OTP for device linking
2. **Given** user receives OTP on new device, **When** they enter correct code, **Then** they can enter their existing PIN to access account
3. **Given** user completes device linking, **When** they log in, **Then** they have full access to their account on the new device

---

### Edge Cases

- What happens when user has no network connection during OTP verification?
- How does system handle phone numbers from different countries/formats?
- What occurs when user receives multiple OTP requests in quick succession?
- How does system behave when Firebase Auth service is temporarily unavailable?
- What happens when user tries to register with a phone number already in use?
- How does system handle users who never receive the OTP due to carrier issues?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST verify phone numbers using Firebase Authentication OTP service
- **FR-002**: System MUST require users to set exactly 4-digit numeric PIN during registration
- **FR-003**: System MUST mask PIN input display (show dots/asterisks instead of numbers)
- **FR-004**: System MUST provide numeric keypad optimized for PIN entry
- **FR-005**: System MUST lock user account after 5 consecutive failed PIN attempts
- **FR-006**: System MUST implement exponential backoff for account lockouts (1min, 5min, 15min, 1hr, 24hr)
- **FR-007**: System MUST store PIN as salted hash in Firestore (never plaintext)
- **FR-008**: System MUST support "Forgot PIN" recovery via phone re-verification
- **FR-009**: System MUST allow OTP resend with 30-second cooldown period
- **FR-010**: System MUST support separate authentication flows for Client and Driver apps
- **FR-011**: System MUST provide full localization support for Arabic, English, and French
- **FR-012**: System MUST log authentication events (start, success, failure) as structured JSON
- **FR-013**: System MUST enforce Firebase App Check in production builds
- **FR-014**: System MUST validate phone number format before sending OTP
- **FR-015**: System MUST expire OTP codes after 5 minutes
- **FR-016**: System MUST prevent registration with invalid or disconnected phone numbers

### Key Entities

- **User Account**: Phone number (unique identifier), PIN hash, salt, account type (client/driver), creation timestamp, last login, lockout status
- **Authentication Session**: User ID, session token, device info, creation time, expiry time
- **Authentication Event**: User ID, event type (login_start, login_success, login_fail, otp_sent, pin_reset), timestamp, device info, IP address
- **Lockout Record**: User ID, failed attempt count, lockout start time, lockout duration, next allowed attempt time

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can complete registration (phone verification + PIN setup) in under 3 minutes
- **SC-002**: Users can log in with phone + PIN in under 30 seconds
- **SC-003**: 95% of OTP messages are delivered within 60 seconds
- **SC-004**: PIN recovery process can be completed in under 2 minutes
- **SC-005**: System maintains 99.9% authentication service availability
- **SC-006**: Authentication works seamlessly across all supported languages (AR/EN/FR)
- **SC-007**: Zero PIN values are stored in plaintext (100% compliance with security requirements)
- **SC-008**: Authentication events are logged with 100% accuracy for audit purposes
- **SC-009**: Lockout mechanism prevents brute force attacks (max 5 attempts before lockout)
- **SC-010**: App Check integration blocks 100% of unauthorized API calls in production