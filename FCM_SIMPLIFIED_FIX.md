# FCM Simplified Fix - No Extra Dependencies

**Date:** 2025-11-12  
**Status:** SIMPLIFIED & SAFE

## Problem
Previous fix added `firebase_installations` dependency unnecessarily.

## Solution
Removed dependency and simplified recovery using only `FirebaseMessaging.deleteToken()`.

## Changes

### 1. Removed Dependencies
**Both pubspec.yaml files:**
- ❌ Removed: `firebase_installations: ^2.0.0`

### 2. Simplified FCM Service (Both Apps)

**Key Changes:**
- Removed `firebase_installations` import
- Removed `_installations` field
- Simplified retry logic with `deleteToken()` for recovery
- Preserved `onTokenRefresh` listener

**Pattern:**
```dart
Future<void> _tryGetAndSaveToken() async {
  const delays = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 6)];
  for (int i = 0; i < delays.length; i++) {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(token);
        return;
      }
    } catch (e) {
      debugPrint('[FCM] getToken attempt ${i + 1} failed: $e');
      try { await _messaging.deleteToken(); } catch (_) {}
    }
    await Future.delayed(delays[i]);
  }
  debugPrint('[FCM] getToken deferred; will rely on onTokenRefresh');
}
```

## How It Works

1. **Request Permission** - Standard FCM setup
2. **Try Get Token** - 3 attempts with exponential backoff (2s, 4s, 6s)
3. **On Failure** - Delete token to force regeneration
4. **Defer to Refresh** - If all attempts fail, `onTokenRefresh` will handle it
5. **Always Listen** - Token refresh listener always active

## Benefits

✅ No extra dependencies  
✅ Simpler code  
✅ Same recovery capability  
✅ Automatic token refresh  
✅ Non-blocking initialization  

## Files Changed

1. `apps/wawapp_client/lib/services/fcm_service.dart` - Simplified
2. `apps/wawapp_driver/lib/services/fcm_service.dart` - Simplified
3. `apps/wawapp_client/pubspec.yaml` - Removed dependency
4. `apps/wawapp_driver/pubspec.yaml` - Removed dependency

## Testing

```bash
.\spec.ps1 flutter:refresh
.\spec.ps1 test:analyze
# 51 issues (no errors, same as before)
```

## Rollback Previous Commit

This replaces the previous fix that added firebase_installations.
