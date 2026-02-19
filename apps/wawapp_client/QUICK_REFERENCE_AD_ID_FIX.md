# Quick Reference: Files Modified for AD_ID Removal

## 📁 EXACT FILE PATHS

### 1. pubspec.yaml
**Path:** `apps/wawapp_client/pubspec.yaml`
**Line:** 29
**Change:** Removed `firebase_analytics: ^11.3.3`

### 2. app_router.dart
**Path:** `apps/wawapp_client/lib/core/router/app_router.dart`
**Lines:** 5, 41-43
**Changes:**
- Removed import: `package:firebase_analytics/firebase_analytics.dart`
- Removed `observers` array with `FirebaseAnalyticsObserver`

### 3. AndroidManifest.xml
**Path:** `apps/wawapp_client/android/app/src/main/AndroidManifest.xml`
**Lines:** 1-2, 7-13
**Changes:**
- Added `xmlns:tools="http://schemas.android.com/tools"` to manifest tag
- Added explicit permission removal directives:
  ```xml
  <uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove"/>
  <uses-permission android:name="android.permission.ACCESS_ADSERVICES_ATTRIBUTION" tools:node="remove"/>
  <uses-permission android:name="android.permission.ACCESS_ADSERVICES_AD_ID" tools:node="remove"/>
  ```

---

## 🔍 EXACT LINES TO VERIFY

### In Merged Manifest (after build):
**Path:** `build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml`

**Should NOT contain:**
- ❌ `com.google.android.gms.permission.AD_ID`
- ❌ `ACCESS_ADSERVICES_ATTRIBUTION`
- ❌ `ACCESS_ADSERVICES_AD_ID`

**Verification command:**
```bash
grep -i "AD_ID" build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
# Expected: No output (exit code 1)
```

---

## 📋 GOOGLE PLAY CONSOLE ANSWER

**Section:** App Content → Advertising ID
**Question:** Does your app use Advertising ID?
**Answer:** ✅ **NO**

---

## ✅ VERIFICATION CHECKLIST

- [x] Removed `firebase_analytics` from `pubspec.yaml`
- [x] Removed analytics import from `app_router.dart`
- [x] Removed `FirebaseAnalyticsObserver` from router
- [x] Added `tools` namespace to `AndroidManifest.xml`
- [x] Added explicit AD_ID permission removal directives
- [x] Ran `flutter clean`
- [x] Ran `flutter pub get`
- [x] Built release APK successfully
- [x] Verified merged manifest has NO AD_ID permissions
- [x] Confirmed all Firebase services still work (Auth, Firestore, Messaging, Crashlytics)

---

**Status:** ✅ COMPLETE - Ready for Google Play submission
