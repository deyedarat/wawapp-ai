# go_router Registry Crash - Reproduction & Verification Guide

## 🔴 Before Fix - How to Reproduce the Crash

### Prerequisites
- WawApp Client or Driver app (version 1.0.0-1.0.1)
- Physical device or emulator
- Logged out state

### Reproduction Steps

#### Method 1: Full Auth Flow (Most Reliable)

1. **Start from logged out state**
   - If logged in, logout first
   - Close and reopen app

2. **Enter phone number**
   - Tap "Login" or "Get Started"
   - Enter valid phone number (e.g., +1234567890)
   - Tap "Send OTP"

3. **Verify OTP quickly**
   - Enter the 6-digit OTP code
   - Tap "Verify" immediately
   - **Don't wait** - speed is key to triggering the race condition

4. **Observe the crash**
   - App should crash within 1-2 seconds
   - Crashlytics will show:
     ```
     io.flutter.plugins.firebase.crashlytics.FlutterError
     'package:go_router/src/state.dart': Failed assertion: line 204 pos 12:
     'registry.containsKey(page)': is not true.
     ```

#### Method 2: Rapid Logout/Login (Alternative)

1. **Login to the app**
2. **Logout immediately**
3. **Login again quickly**
4. **Verify OTP**
5. **Crash should occur** during the rapid state transitions

### Why It Crashes

The crash happens because:
1. OTP verification triggers auth state change → redirect to /pin-gate
2. PIN status check completes → redirect to /
3. Both redirects fire within ~50ms
4. go_router's page registry can't keep up
5. Second redirect tries to access a page that's not in the registry yet
6. **BOOM**: `assert(registry.containsKey(page))` fails

### Crash Frequency

- **High** (70-80%): On slower devices or when network is slow
- **Medium** (40-50%): On fast devices with good network
- **Low** (10-20%): If there's a delay between OTP verification and PIN check

---

## ✅ After Fix - Verification Steps

### Prerequisites
- WawApp Client or Driver app with fix applied
- Physical device or emulator
- Logged out state

### Verification Test 1: Full Auth Flow

1. **Start from logged out state**
2. **Enter phone number** → Send OTP
3. **Enter OTP** → Verify
4. **Wait for navigation** to complete

**Expected Result**:
- ✅ Smooth navigation: Login → OTP → PIN Gate → Home
- ✅ No crashes
- ✅ Logs show debounced redirect:
  ```
  [Router] Auth state changed, triggering redirect check | user=abc123 | pinStatus=hasPin | otpStage=verified
  ```

### Verification Test 2: Rapid State Changes

1. **Login** to the app
2. **Logout** immediately
3. **Login again** quickly
4. **Verify OTP** as fast as possible

**Expected Result**:
- ✅ Smooth navigation despite rapid changes
- ✅ No crashes
- ✅ Logs show debouncing working:
  ```
  [Router] Auth state changed, triggering redirect check | user=null | pinStatus=unknown | otpStage=idle
  [Router] Auth state changed, triggering redirect check | user=null | pinStatus=unknown | otpStage=sending
  [Router] Auth state changed, triggering redirect check | user=abc123 | pinStatus=loading | otpStage=verified
  ```

### Verification Test 3: Normal Navigation

1. **Navigate** between screens normally:
   - Home → Profile → Edit Profile → Back
   - Home → Notifications → Back
   - Home → Track Order → Back

**Expected Result**:
- ✅ All navigation works normally
- ✅ No crashes
- ✅ No regression in behavior

### Verification Test 4: Edge Cases

#### Test 4a: App Backgrounding During Auth
1. **Start OTP verification**
2. **Background the app** (press home button)
3. **Return to app** after 5 seconds
4. **Complete verification**

**Expected Result**:
- ✅ Navigation completes correctly
- ✅ No crashes

#### Test 4b: Network Interruption
1. **Start OTP verification**
2. **Disable network** briefly
3. **Re-enable network**
4. **Complete verification**

**Expected Result**:
- ✅ Error handling works correctly
- ✅ No crashes
- ✅ User can retry

#### Test 4c: Multiple Rapid Taps
1. **On login screen**, tap "Send OTP" multiple times rapidly
2. **On OTP screen**, tap "Verify" multiple times rapidly

**Expected Result**:
- ✅ Debouncing prevents duplicate requests
- ✅ No crashes
- ✅ Only one navigation occurs

---

## 📊 Monitoring After Deployment

### Crashlytics Checks

**Week 1 After Deployment**:
- [ ] Check Crashlytics daily
- [ ] Confirm **zero** `registry.containsKey(page)` crashes
- [ ] Monitor for any new navigation-related crashes

**Week 2-4 After Deployment**:
- [ ] Check Crashlytics weekly
- [ ] Confirm sustained absence of registry crashes
- [ ] Verify no regression in other metrics

### Log Analysis

**Look for these patterns in logs**:

✅ **Good** - Debouncing working:
```
[Router] Auth state changed, triggering redirect check | user=abc123 | pinStatus=hasPin | otpStage=verified
[Router] NAVIGATION_CHECK | location=/ | user=abc123 | pinStatus=hasPin | canOtp=false | otpStage=verified | isLoading=false
[Router] ✓ Authenticated - allowing access to /
```

⚠️ **Warning** - Rapid changes (but handled safely):
```
[Router] Auth state changed, triggering redirect check | user=null | pinStatus=unknown | otpStage=idle
[Router] Auth state changed, triggering redirect check | user=abc123 | pinStatus=loading | otpStage=verified
[Router] Auth state changed, triggering redirect check | user=abc123 | pinStatus=hasPin | otpStage=verified
```

❌ **Bad** - Should NOT see:
```
FlutterError: 'package:go_router/src/state.dart': Failed assertion: line 204 pos 12: 'registry.containsKey(page)': is not true.
```

---

## 🧪 Automated Testing (Optional)

### Integration Test

Create a test that simulates rapid auth state changes:

```dart
testWidgets('Rapid auth state changes should not crash', (tester) async {
  // Setup
  await tester.pumpWidget(MyApp());
  
  // Trigger rapid state changes
  final authNotifier = container.read(authProvider.notifier);
  
  // Simulate: logout → login → OTP → verify → PIN check
  await authNotifier.logout();
  await tester.pump();
  
  await authNotifier.sendOtp('+1234567890');
  await tester.pump();
  
  await authNotifier.verifyOtp('123456');
  await tester.pump();
  
  // Wait for debouncing
  await tester.pump(Duration(milliseconds: 150));
  
  // Verify no crash
  expect(find.byType(HomeScreen), findsOneWidget);
});
```

---

## 📝 Checklist for QA

### Pre-Deployment Testing

- [ ] Test full auth flow 10 times (should pass 10/10)
- [ ] Test rapid logout/login 5 times (should pass 5/5)
- [ ] Test normal navigation (should work as before)
- [ ] Test edge cases (backgrounding, network interruption)
- [ ] Check logs for debouncing messages
- [ ] Verify no crashes in test environment

### Post-Deployment Monitoring

**Day 1**:
- [ ] Check Crashlytics for registry crashes (should be 0)
- [ ] Monitor user reports for navigation issues
- [ ] Review logs for any unexpected patterns

**Week 1**:
- [ ] Daily Crashlytics check
- [ ] Compare crash rate to pre-fix baseline
- [ ] Verify fix is working in production

**Week 2-4**:
- [ ] Weekly Crashlytics check
- [ ] Confirm sustained improvement
- [ ] Document any edge cases discovered

---

## 🎯 Success Criteria

### Must Have (P0)
- ✅ Zero `registry.containsKey(page)` crashes in Crashlytics
- ✅ Auth flow completes successfully 100% of the time
- ✅ No regression in existing navigation behavior

### Should Have (P1)
- ✅ Logs show debouncing working correctly
- ✅ Navigation feels smooth (no noticeable delay from 100ms debounce)
- ✅ User reports no navigation issues

### Nice to Have (P2)
- ✅ Improved navigation performance (fewer unnecessary redirects)
- ✅ Better observability via enhanced logging
- ✅ Easier to debug future navigation issues

---

## 🚨 Rollback Triggers

**Rollback immediately if**:
- New navigation crashes appear (different from registry crash)
- Auth flow success rate drops below 95%
- Users report being stuck on auth screens

**Investigate before rollback if**:
- Minor increase in navigation-related issues (< 1% of users)
- Logs show unexpected patterns but no crashes
- Performance concerns (debounce delay too noticeable)

---

**Status**: ✅ **READY FOR TESTING**

**Next Steps**:
1. Apply fix to staging environment
2. Run verification tests
3. Monitor for 24-48 hours
4. Deploy to production if all tests pass
5. Monitor production for 1 week
