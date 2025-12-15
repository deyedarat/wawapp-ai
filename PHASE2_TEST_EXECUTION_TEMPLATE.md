# Phase 2: Manual Test Execution Log

**Test Date**: ___________  
**Tester Name**: ___________  
**App Version**: ___________  
**Device**: ___________  
**OS**: ___________

---

## Test Case Execution Results

### AUTH FLOWS

#### TC-01: Kill app during phone verification
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Enter phone number, request OTP
2. [ ] Force-stop app before entering OTP
3. [ ] Restart app

**Expected Result**:
- User returns to phone verification screen OR login screen
- Can request new OTP

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `auth_verification_interrupted` breadcrumb present
- [ ] `auth_state: verification_pending` in Crashlytics user attributes
- [ ] No crash on restart

**Evidence** (screenshots/logs):  
_________________________________

---

#### TC-02: Token expires during active session
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Manipulate token TTL to expire in 30s (or wait for natural expiry)
2. [ ] Wait for token expiration
3. [ ] Attempt auth-required action (create order, view profile)

**Expected Result**:
- Token auto-refreshes silently OR user shown "session expired, please login"

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `token_refresh_attempt` logged
- [ ] `token_refresh_success` or `token_refresh_failed` logged
- [ ] No crash, no infinite spinner

**Evidence**:  
_________________________________

---

#### TC-03: Logout with active order
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Client has active order (status: accepted or in_progress)
2. [ ] Tap logout, confirm
3. [ ] Re-login with same account

**Expected Result**:
- After re-login, active order visible with correct state

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `logout_with_active_order` logged with orderId
- [ ] Order status unchanged in Firestore during logout
- [ ] `order_state_restored` logged on re-login

**Evidence**:  
_________________________________

---

### CLIENT ORDER FLOWS

#### TC-04: Create order → offline → online
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Fill order details (pickup, dropoff)
2. [ ] Enable airplane mode
3. [ ] Tap "Create Order"
4. [ ] Wait 5 seconds
5. [ ] Disable airplane mode

**Expected Result**:
- User sees error "No connection, please try again"

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_create_failed: network_unavailable` logged
- [ ] No silent failure (no bad data in Firestore /orders collection)
- [ ] User not stuck on loading screen

**Evidence**:  
_________________________________

---

#### TC-05: Background app after order created
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Create order (status: pending)
2. [ ] Immediately background app (home button)
3. [ ] Wait 30 seconds
4. [ ] Return to app

**Expected Result**:
- Order screen shows current state
- If driver accepted, driver info visible

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `app_backgrounded` with orderId logged
- [ ] `app_foregrounded` with orderId logged
- [ ] Firestore listener reconnected (UI matches Firestore state)

**Evidence**:  
_________________________________

---

#### TC-06: Kill app after order accepted
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Driver accepts order
2. [ ] Client sees driver details
3. [ ] Force-stop client app
4. [ ] Restart app

**Expected Result**:
- App opens to active order screen showing driver info, map, status

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `app_killed_with_active_order` logged on restart
- [ ] `active_order_restored: {orderId}` logged
- [ ] No duplicate order created (verify in Firestore)

**Evidence**:  
_________________________________

---

### DRIVER ORDER FLOWS

#### TC-07: Accept order → kill app → restart
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Driver taps "Accept Order"
2. [ ] Wait for acceptance confirmation
3. [ ] Force-stop driver app
4. [ ] Restart app

**Expected Result**:
- Driver sees active order with client details
- Firestore shows order assigned to driver

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_accepted: {orderId}` logged before kill
- [ ] `active_order_restored: {orderId}` logged on restart
- [ ] Order status NOT rolled back to pending in Firestore

**Evidence**:  
_________________________________

---

#### TC-08: Go offline during active trip
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Driver has order status: in_progress (trip started)
2. [ ] Driver taps "Go Offline"

**Expected Result**:
- Action BLOCKED with message "Cannot go offline during active trip"

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `go_offline_blocked: active_trip` logged
- [ ] Driver `isOnline` NOT changed in Firestore /drivers/{driverId}
- [ ] No orphaned trip

**Evidence**:  
_________________________________

---

#### TC-09: Complete trip → kill app
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Driver taps "Complete Order"
2. [ ] Wait 2 seconds (payment processing)
3. [ ] Force-stop app before confirmation screen
4. [ ] Restart app

**Expected Result**:
- Order shows as completed in Firestore
- Driver sees completion summary OR returns to available orders list

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_completed: {orderId}` logged before kill
- [ ] Payment transaction ID logged
- [ ] No duplicate completion writes (check Firestore timestamps)

**Evidence**:  
_________________________________

---

### NETWORK RESILIENCE

#### TC-10: Airplane mode during order creation
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Enter pickup/dropoff
2. [ ] Enable airplane mode
3. [ ] Tap "Create Order"

**Expected Result**:
- Error message "No internet connection" shown immediately
- No loading spinner

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_create_failed: offline` logged
- [ ] NO write attempted to Firestore /orders collection
- [ ] No crash

**Evidence**:  
_________________________________

---

#### TC-11: Slow network timeout (simulated 3G)
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Throttle network to 3G speed (or use physical 3G)
2. [ ] Client creates order
3. [ ] Wait for response

**Expected Result**:
- Order created within 10s OR timeout error shown "Request timed out, please retry"

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_create_timeout` logged if >10s
- [ ] No infinite spinner (timeout enforced)
- [ ] User can retry

**Evidence**:  
_________________________________

---

#### TC-12: Firestore write fails (simulate permission denied)
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Modify Firestore rules to deny write (test environment only)
2. [ ] Attempt to create order

**Expected Result**:
- User sees error "Failed to create order, please try again"

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `firestore_write_failed: {collection, error_code}` logged
- [ ] Error surfaced to UI (not silent)
- [ ] Crashlytics non-fatal logged

**Evidence**:  
_________________________________

---

### APP LIFECYCLE

#### TC-13: Background for 10 mins → return
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Open app (no active order)
2. [ ] Background app
3. [ ] Wait 10 minutes
4. [ ] Return to app

**Expected Result**:
- App shows current state
- Firestore listeners reconnect
- No crash

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `app_backgrounded` with timestamp logged
- [ ] `app_foregrounded` with timestamp logged
- [ ] `listeners_reconnected` logged (implicit, check data freshness)

**Evidence**:  
_________________________________

---

#### TC-14: Force-stop with active order
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Client has active order (status: in_progress)
2. [ ] Force-stop app
3. [ ] Restart app

**Expected Result**:
- App restores to active order screen
- State matches Firestore

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `app_force_stopped` detected on restart
- [ ] `active_order_restored: {orderId}` logged
- [ ] State verified against Firestore (no stale cache)

**Evidence**:  
_________________________________

---

#### TC-15: Rapidly switch apps during order creation
**Status**: ⏳ PENDING / ✅ PASS / ❌ FAIL

**Steps Executed**:
1. [ ] Fill order form
2. [ ] Tap "Create Order"
3. [ ] Immediately switch to another app (within 1s)
4. [ ] Return to WawApp
5. [ ] Check Firestore orders collection

**Expected Result**:
- Exactly ONE order created
- No duplicates

**Actual Result**:  
_________________________________

**Logs/Signals Verified**:
- [ ] `order_create_initiated: {tempId}` logged
- [ ] `order_create_success: {orderId}` logged once
- [ ] Firestore write idempotency verified (single order with matching tempId)

**Evidence**:  
_________________________________

---

## Summary

**Total Test Cases**: 15  
**Passed**: _____ / 15  
**Failed**: _____ / 15  
**Pending**: _____ / 15

**Phase 2 Ready for Next Stage**: ⏳ YES / ❌ NO

**Critical Issues Discovered**:  
_________________________________

**Notes**:  
_________________________________

**Sign-off**:  
**QA Tester**: ___________  
**Date**: ___________
