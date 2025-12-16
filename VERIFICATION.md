# Observability Verification Guide

This document explains how to verify that Crashlytics breadcrumbs, custom keys, and non-fatal errors are working correctly in the WawApp.

## Prerequisites

1. **Build and Run the App**: Deploy the app to a physical device or emulator with Firebase Crashlytics enabled
2. **Firebase Console Access**: Open [Firebase Console](https://console.firebase.google.com) → Your Project → Crashlytics
3. **Wait Time**: Crashlytics may take 5-15 minutes to show new data in the dashboard

---

## 1. Verifying Breadcrumbs

Breadcrumbs appear in Crashlytics crash reports under the **"Logs"** tab of each crash or non-fatal event.

### How to Verify:

1. **Trigger Events in the App**:
   - Launch the app → `app_launched` breadcrumb
   - Go to login screen and enter phone → `login_attempt` breadcrumb
   - Complete login successfully → `login_success` breadcrumb
   - Attempt login with wrong OTP → `login_failed` breadcrumb
   - Start creating an order → `order_create_attempt` breadcrumb
   - Let order creation fail (e.g., disable network) → `order_create_failed` breadcrumb
   - Put app in background → `app_backgrounded` breadcrumb

2. **Trigger a Test Crash** (to see breadcrumbs in a report):
   ```dart
   // Add this button in debug menu or any screen:
   FirebaseCrashlytics.instance.crash();
   ```

3. **View in Firebase Console**:
   - Firebase Console → Crashlytics → Click on the crash event
   - Scroll to **"Logs"** section
   - You should see breadcrumbs in this format:
     ```
     [2024-12-16T10:23:45.123Z] app_launched
     [2024-12-16T10:24:12.456Z] login_attempt | screen=phone_login | phone=+1234567890
     [2024-12-16T10:24:18.789Z] login_success | userId=abc123 | screen=auth_gate
     [2024-12-16T10:25:30.012Z] order_create_attempt | userId=abc123 | screen=quote_screen
     [2024-12-16T10:26:45.345Z] app_backgrounded | userId=abc123
     ```

### Expected Format:
Each breadcrumb includes:
- `timestamp`: ISO 8601 format
- `action`: The event name (e.g., `login_attempt`)
- `userId`: When user is authenticated
- `screen`: Current screen name
- Additional context as needed

---

## 2. Verifying Custom Keys

Custom keys appear in **every** Crashlytics event under the **"Keys"** tab.

### How to Verify:

1. **Trigger Any Event** (crash or non-fatal):
   ```dart
   // Trigger a non-fatal error to see keys:
   try {
     throw Exception('Test non-fatal error');
   } catch (e, stack) {
     FirebaseCrashlytics.instance.recordError(e, stack, fatal: false);
   }
   ```

2. **View in Firebase Console**:
   - Firebase Console → Crashlytics → Click on any event
   - Look for **"Keys"** section (may be under "Custom keys" tab)
   - You should see these 7 keys:

   | Key | Example Value | Set When |
   |-----|---------------|----------|
   | `user_id` | `abc123xyz` | User logs in |
   | `user_role` | `client` or `driver` | User logs in |
   | `auth_state` | `authenticated`, `unauthenticated`, `initial` | Auth changes |
   | `active_order_id` | `order_xyz123` or `none` | Order created/cleared |
   | `app_version` | `1.0.1` | App launch |
   | `platform` | `android` or `ios` | App launch |
   | `network_type` | `wifi`, `mobile`, `unknown` | App launch or network change |

### Testing Scenarios:
- **Before login**: `auth_state=initial`, `user_id` not set
- **After login**: `auth_state=authenticated`, `user_id=<firebase_uid>`, `user_role=client`
- **After order created**: `active_order_id=<order_id>`
- **After logout**: `auth_state=unauthenticated`, `user_id` cleared

---

## 3. Verifying Non-Fatal Errors

Non-fatal errors appear in Crashlytics as **separate events** that don't crash the app.

### The 3 Required Non-Fatal Types:

#### A. **Firestore Write Failure**

**How to Trigger**:
1. Turn on Airplane Mode or disable network
2. Try to create an order in the app
3. The order creation will fail

**Expected in Crashlytics**:
- Event Type: Non-fatal
- Error message: Contains "order_create_failed" or Firestore error
- Stack trace: Shows `OrdersRepository.createOrder`
- Logs: Shows `order_create_failed` breadcrumb
- Keys: Shows `user_id`, `auth_state`, etc.

**Code Location**:
```dart
// packages/auth_shared/lib/src/auth_notifier.dart
// apps/wawapp_client/lib/features/track/data/orders_repository.dart
WawLog.e('orders_repository', 'Order creation failed', e, stackTrace);
```

#### B. **Network Unavailable**

**How to Trigger**:
1. Turn off network connectivity
2. Try to perform any operation that requires network (login, create order, fetch orders)

**Expected in Crashlytics**:
- Event Type: Non-fatal
- Error message: Contains "network" or "unavailable"
- Logs: May show `login_failed` or `order_create_failed` breadcrumb
- Keys: `network_type=unknown` or offline state

**Code Location**:
```dart
// Any Firestore operation will trigger this when offline
// The WawLog.e calls in auth_notifier.dart and orders_repository.dart
```

#### C. **Unexpected Exception**

**How to Trigger**:
1. Any unhandled exception in try-catch blocks
2. Example: Invalid phone format during login
3. Example: Malformed data from Firestore

**Expected in Crashlytics**:
- Event Type: Non-fatal
- Error message: The specific exception message
- Stack trace: Shows where the exception occurred
- Logs: Relevant breadcrumbs leading up to the error

**Code Location**:
```dart
// apps/wawapp_client/lib/main.dart
WawLog.e('main', 'Firebase initialization failed', e, stack);

// packages/auth_shared/lib/src/auth_notifier.dart
WawLog.e('auth_notifier', 'Phone session failed', e, stackTrace);
WawLog.e('auth_notifier', 'OTP verification failed', e, stackTrace);
```

---

## 4. Verification Checklist

Use this checklist to confirm everything is working:

### Breadcrumbs (6 required)
- [ ] `app_launched` - Visible in logs when app starts
- [ ] `login_attempt` - Visible when user enters phone
- [ ] `login_success` - Visible when OTP succeeds
- [ ] `login_failed` - Visible when OTP fails
- [ ] `order_create_attempt` - Visible when order creation starts
- [ ] `order_create_failed` - Visible when order creation fails
- [ ] `app_backgrounded` - Visible when app goes to background

### Custom Keys (7 required)
- [ ] `user_id` - Shows Firebase UID after login
- [ ] `user_role` - Shows "client" or "driver"
- [ ] `auth_state` - Shows "authenticated", "unauthenticated", or "initial"
- [ ] `active_order_id` - Shows order ID or "none"
- [ ] `app_version` - Shows app version (e.g., "1.0.1")
- [ ] `platform` - Shows "android" or "ios"
- [ ] `network_type` - Shows "wifi", "mobile", or "unknown"

### Non-Fatal Events (3 required)
- [ ] **Firestore write failure** - Network off, try create order
- [ ] **Network unavailable** - Network off, any operation
- [ ] **Unexpected exception** - Invalid input or edge case error

---

## 5. Troubleshooting

### "I don't see any data in Crashlytics"

**Possible Reasons**:
1. **Crashlytics not initialized**: Check that `CrashlyticsObserver.initialize()` is called in `main.dart`
2. **Debug mode disabled**: Crashlytics collection may be disabled in debug. Check:
   ```dart
   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
   ```
3. **Data delay**: Wait 10-15 minutes for data to appear
4. **No events triggered**: Trigger a crash or non-fatal to force upload

### "Breadcrumbs are missing"

**Check**:
1. Is `BreadcrumbService.initialize()` called in `main.dart`?
2. Are breadcrumb methods being called before events?
3. Trigger a crash to see breadcrumbs in the crash report

### "Custom keys not showing"

**Check**:
1. Is `CrashlyticsKeys.initialize()` called in `main.dart`?
2. Are keys being set at the right lifecycle points (login, app launch)?
3. Trigger any event to see keys attached to that event

---

## 6. Quick Test Script

Run this sequence to verify all functionality:

```
1. Clean install app
   → Check: app_launched breadcrumb, initial custom keys

2. Navigate to login, enter phone, request OTP
   → Check: login_attempt breadcrumb

3. Enter wrong OTP code
   → Check: login_failed breadcrumb, non-fatal event

4. Enter correct OTP code
   → Check: login_success breadcrumb, user_id key set

5. Start creating an order
   → Check: order_create_attempt breadcrumb

6. Turn off network, try to complete order
   → Check: order_create_failed breadcrumb, non-fatal event

7. Press home button to background app
   → Check: app_backgrounded breadcrumb

8. Go to Firebase Console → Crashlytics
   → Verify: All breadcrumbs, keys, and non-fatal events appear
```

---

## Notes

- **Breadcrumbs** are only visible within crash/non-fatal event reports (in the "Logs" tab)
- **Custom Keys** appear in every event (in the "Keys" tab)
- **Non-Fatal Events** appear as separate events in the Crashlytics dashboard
- Data may take 5-15 minutes to appear in the Firebase Console
- Use **Test Mode** to force immediate crash report upload: `FirebaseCrashlytics.instance.crash()`
