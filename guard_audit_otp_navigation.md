# Guard Audit Report: OTP Navigation Flow

**Date:** 2025-01-27  
**Branch:** feat/phase1-fcm-setup  
**Scope:** Phone/PIN → OTP flow guard patterns in both wawapp_client and wawapp_driver  

## Executive Summary

This audit examined guard patterns in the authentication flow, focusing on IME-safe navigation, context safety, and state management. Several critical issues were identified that could lead to navigation failures, context misuse, and duplicate operations.

## Findings by Category

### 1. Navigation Guards

#### ✅ GOOD: Single Navigation Prevention
**File:** `apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart:18`
```dart
bool _navigatedThisAttempt = false;
```
- Proper flag to prevent duplicate navigation
- Reset on new attempts (line 85)

**File:** `apps/wawapp_driver/lib/features/auth/phone_pin_login_screen.dart:19`
```dart
bool _navigatedThisAttempt = false;
```
- Same pattern implemented consistently

#### ✅ GOOD: IME-Safe Navigation
**File:** `apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart:38`
```dart
FocusScope.of(context).unfocus();
```
- Keyboard closed before navigation

**File:** `apps/wawapp_driver/lib/features/auth/phone_pin_login_screen.dart:42`
```dart
FocusScope.of(context).unfocus();
```
- Consistent IME handling

#### ✅ GOOD: Post-Frame Navigation
Both apps use `WidgetsBinding.instance.addPostFrameCallback` to ensure navigation happens after frame completion.

### 2. Context/Mounted Guards

#### ❌ CRITICAL: Missing context.mounted in Client App
**File:** `apps/wawapp_client/lib/features/auth/otp_screen.dart:28`
```dart
ref.listen<AuthState>(authProvider, (previous, next) {
  if (next.user != null && !next.otpFlowActive && !next.isLoading) {
    if (!context.mounted) return; // ✅ GOOD
    Navigator.pushReplacement(
      context, // ❌ POTENTIAL ISSUE: No additional mounted check before usage
      MaterialPageRoute(builder: (_) => const CreatePinScreen()),
    );
  }
});
```

#### ✅ GOOD: Proper context.mounted in Driver App
**File:** `apps/wawapp_driver/lib/features/auth/otp_screen.dart:35-55`
```dart
if (!context.mounted) return;
// ... operations
if (!context.mounted) return;
context.go('/');
```
- Multiple mounted checks before each context usage

#### ❌ CRITICAL: Inconsistent mounted checks in Client App
**File:** `apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart:53-58`
```dart
if (next.user != null && !next.isLoading && mounted) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) { // ❌ Should be context.mounted
      Navigator.of(context).pushReplacementNamed('/');
    }
  });
}
```

### 3. State Guards

#### ✅ GOOD: OTP Stage Guards
**File:** `apps/wawapp_client/lib/features/auth/providers/auth_service_provider.dart:108-113`
```dart
if (state.otpStage == OtpStage.sending ||
    state.otpStage == OtpStage.codeSent) {
  debugPrint('[AuthNotifier] sendOtp blocked: already ${state.otpStage}');
  return;
}
```

#### ✅ GOOD: Button Disabled During Operations
Both apps disable buttons during loading states:
```dart
onPressed: (authState.isLoading ||
    authState.otpStage == OtpStage.sending ||
    authState.otpStage == OtpStage.codeSent) ? null : _continue,
```

### 4. Re-entrancy & Duplicates

#### ❌ MISSING: SMS Button Throttling in Driver App
**File:** `apps/wawapp_driver/lib/features/auth/phone_pin_login_screen.dart:95-105`
```dart
void _handleOtpFlow() {
  // ❌ No throttling/debouncing mechanism
  // ❌ No disabled state during OTP sending
}
```

#### ✅ GOOD: Continue Button Guards
Both apps properly disable the Continue button during operations.

### 5. Error/Edge Guards

#### ✅ GOOD: Phone Format Validation
**Driver App:** Uses proper E.164 regex validation
**Client App:** Basic validation with user-friendly error

#### ❌ MISSING: Network Error Recovery
Neither app has explicit network error recovery mechanisms for failed OTP sends.

### 6. IME/Focus Guards

#### ✅ GOOD: Controller Disposal
Both apps properly dispose TextEditingController instances in dispose() methods.

#### ✅ GOOD: Keyboard Dismissal
Both apps call `FocusScope.of(context).unfocus()` before navigation.

## Critical Issues Requiring Fixes

### Issue 1: Inconsistent mounted checks in Client App
**Severity:** HIGH  
**File:** `apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart:57`  
**Problem:** Using `mounted` instead of `context.mounted`  
**Fix:**
```diff
- if (mounted) {
+ if (context.mounted) {
```

### Issue 2: Missing context.mounted before Navigator usage in OtpScreen
**Severity:** HIGH  
**File:** `apps/wawapp_client/lib/features/auth/otp_screen.dart:30`  
**Problem:** No mounted check immediately before Navigator.pushReplacement  
**Fix:**
```diff
  if (next.user != null && !next.otpFlowActive && !next.isLoading) {
    if (!context.mounted) return;
+   // Add delay to ensure context is still valid
+   WidgetsBinding.instance.addPostFrameCallback((_) {
+     if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreatePinScreen()),
      );
+   });
  }
```

### Issue 3: SMS Button Not Disabled During OTP Flow
**Severity:** MEDIUM  
**File:** `apps/wawapp_driver/lib/features/auth/phone_pin_login_screen.dart:158`  
**Problem:** SMS button remains enabled during OTP sending  
**Fix:**
```diff
TextButton(
- onPressed: authState.isLoading ? null : _handleOtpFlow,
+ onPressed: (authState.isLoading || 
+            authState.otpStage == OtpStage.sending ||
+            authState.otpStage == OtpStage.codeSent) ? null : _handleOtpFlow,
  child: const Text('New device or forgot PIN? Verify by SMS'),
),
```

## Static Analysis Results

### Client App Issues:
- 1 `use_build_context_synchronously` warning in quote_screen.dart (unrelated)
- Test-related warnings (unused imports, variables)

### Driver App Issues:
- 26 style issues (mostly `always_put_control_body_on_new_line`)
- 1 uninitialized field type annotation issue
- Multiple catch clause improvements needed

## Verification Steps

1. **Navigation Test:** Verify single navigation to OTP screen
2. **IME Test:** Confirm keyboard closes before navigation
3. **Context Test:** Ensure no context usage across async gaps
4. **Button State Test:** Verify buttons disabled during operations
5. **Error Handling Test:** Test invalid phone format and network errors

## Recommendations

1. **Immediate:** Fix critical context.mounted issues
2. **Short-term:** Add SMS button state management
3. **Long-term:** Implement comprehensive error recovery
4. **Testing:** Add widget tests for guard behaviors

## Proposed Fixes

The following minimal changes address the critical issues:

### Fix 1: Client App Context Guards
```diff
// apps/wawapp_client/lib/features/auth/phone_pin_login_screen.dart
@@ -54,7 +54,7 @@
         if (next.user != null && !next.isLoading && mounted) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
-            if (mounted) {
+            if (context.mounted) {
               Navigator.of(context).pushReplacementNamed('/');
             }
           });
```

### Fix 2: Client App OTP Screen Context Safety
```diff
// apps/wawapp_client/lib/features/auth/otp_screen.dart
@@ -27,9 +27,13 @@
     ref.listen<AuthState>(authProvider, (previous, next) {
       if (next.user != null && !next.otpFlowActive && !next.isLoading) {
         if (!context.mounted) return;
-        Navigator.pushReplacement(
-          context,
-          MaterialPageRoute(builder: (_) => const CreatePinScreen()),
-        );
+        WidgetsBinding.instance.addPostFrameCallback((_) {
+          if (!context.mounted) return;
+          Navigator.pushReplacement(
+            context,
+            MaterialPageRoute(builder: (_) => const CreatePinScreen()),
+          );
+        });
       }
     });
```

### Fix 3: Driver App SMS Button State
```diff
// apps/wawapp_driver/lib/features/auth/phone_pin_login_screen.dart
@@ -155,7 +155,10 @@
             ),
             TextButton(
-              onPressed: authState.isLoading ? null : _handleOtpFlow,
+              onPressed: (authState.isLoading ||
+                         authState.otpStage == OtpStage.sending ||
+                         authState.otpStage == OtpStage.codeSent)
+                  ? null : _handleOtpFlow,
               child: const Text('New device or forgot PIN? Verify by SMS'),
             ),
```

## Conclusion

The audit identified 3 critical issues and several improvement opportunities. The guard patterns are generally well-implemented, with proper IME handling and navigation prevention. The main concerns are around context safety and button state management. After applying the proposed fixes, the OTP navigation flow will be robust and IME-safe.

**Status:** REQUIRES FIXES  
**Next Steps:** Apply proposed diffs, test navigation flow, commit changes