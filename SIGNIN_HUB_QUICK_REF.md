# SignInHubActivity Crash - Quick Reference

## 🔴 The Problem

**Crash**: `NullPointerException` in `SignInHubActivity.onCreate()`  
**Frequency**: Intermittent, production-only  
**Impact**: App crashes unexpectedly for some users

---

## 🔍 Root Cause

**NOT** a Google Sign-In feature - it's a **transitive dependency**:

```
Firebase Auth → credentials-play-services-auth → play-services-auth:20.7.0
```

Version **20.7.0** has poor null handling when Play Services tries to auto-recover sessions.

---

## ✅ The Fix

Force upgrade to `play-services-auth:21.2.0`:

```kotlin
// apps/wawapp_client/android/app/build.gradle.kts
// apps/wawapp_driver/android/app/build.gradle.kts
dependencies {
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}
```

---

## 🚀 Apply Fix

```bash
# Apply patch
git apply signin_hub_crash_fix.patch

# Clean build
cd apps/wawapp_client
flutter clean && flutter pub get && flutter build apk --release

cd ../wawapp_driver
flutter clean && flutter pub get && flutter build apk --release

# Verify
cd android
./gradlew :app:dependencies | grep "play-services-auth:21.2.0"
```

---

## ✅ Verification

1. **Build**: Both apps compile cleanly
2. **Install**: Uninstall old version, install new APK
3. **Test**: Complete auth flow on 2+ devices
4. **Monitor**: Check Crashlytics for 48 hours

**Expected**: Zero SignInHubActivity crashes

---

## 📊 Impact

- **Before**: play-services-auth:20.7.0 (NPE crashes)
- **After**: play-services-auth:21.2.0 (fixed null handling)
- **Risk**: Low (backward compatible, no code changes)

---

**Status**: ✅ **READY** - Apply patch and deploy
