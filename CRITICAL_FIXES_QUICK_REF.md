# Critical Fixes - Quick Reference

## 🚀 Quick Start

```bash
# 1. Rebuild apps
cd apps/wawapp_client
flutter clean && flutter pub get

# 2. Deploy indexes
cd ../..
firebase deploy --only firestore:indexes

# 3. Run on device
cd apps/wawapp_client
flutter run
```

---

## ✅ What Was Fixed

| Issue | Status | Action Required |
|-------|--------|-----------------|
| Firebase duplicate app | ✅ Fixed | None |
| Maps authorization | ⚠️ Config needed | Add SHA-1 to Firebase |
| Performance (277 frames) | ✅ Fixed | None |
| Firestore indexes | ✅ Ready | Deploy indexes |

---

## ⚠️ Manual Steps Required

### 1. Firebase Console - Add SHA-1
```
SHA-1: BA:DB:92:8D:91:F4:56:C8:F3:35:0C:E4:54:C3:80:C2:0F:54:EA:76
```
1. https://console.firebase.google.com
2. Project Settings → Android app (com.wawapp.client)
3. Add fingerprint
4. Download new google-services.json
5. Replace in `apps/wawapp_client/android/app/`

### 2. Google Cloud - Enable Maps SDK
1. https://console.cloud.google.com
2. APIs & Services → Library
3. Search "Maps SDK for Android"
4. Click Enable

### 3. Deploy Firestore Indexes
```bash
firebase deploy --only firestore:indexes
```
Wait 5-30 minutes for build completion

---

## 📊 Verification

```bash
# No duplicate app error
adb logcat | findstr "duplicate-app"
# Expected: No output

# No maps auth error (after Firebase config)
adb logcat | findstr "Authorization failure"
# Expected: No output

# Minimal frame drops
adb logcat | findstr "Skipped.*frames"
# Expected: <10 frames

# No index errors (after deployment)
adb logcat | findstr "FAILED_PRECONDITION"
# Expected: No output
```

---

## 📚 Documentation

- **Firebase Init:** `docs/FIREBASE_INIT_FLOW.md`
- **Maps Setup:** `docs/MAPS_SETUP_CLIENT.md`
- **Performance:** `docs/PERFORMANCE_ISSUES_CLIENT.md`
- **Indexes:** `docs/FIRESTORE_INDEXES.md`
- **Full Summary:** `docs/CRITICAL_FIXES_SUMMARY.md`

---

## 🔧 Files Changed

### Modified (4)
- `apps/wawapp_driver/lib/main.dart`
- `apps/wawapp_client/lib/features/home/home_screen.dart`
- `packages/core_shared/lib/core_shared.dart`
- `firestore.indexes.json` (no changes)

### Created (5)
- `packages/core_shared/lib/src/observability/firebase_bootstrap.dart`
- `docs/FIREBASE_INIT_FLOW.md`
- `docs/MAPS_SETUP_CLIENT.md`
- `docs/PERFORMANCE_ISSUES_CLIENT.md`
- `docs/FIRESTORE_INDEXES.md`

---

## ✅ Checklist

- [ ] Code changes applied
- [ ] Apps rebuild successfully
- [ ] SHA-1 added to Firebase Console
- [ ] Maps SDK enabled
- [ ] New google-services.json downloaded
- [ ] Firestore indexes deployed
- [ ] Tested on physical device
- [ ] No error logs
- [ ] Performance improved

---

**Need Help?** See `docs/CRITICAL_FIXES_SUMMARY.md` for detailed information.
