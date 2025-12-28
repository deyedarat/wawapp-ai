# WawApp Status Report

**Generated:** 2025-11-12T145330  
**Branch:** feat/phase3-analytics-deeplinks

## Recent Commits

```
daaef45 chore(speckit): unify build/test commands + Amazon Q prewarm setup
18bf312 feat(auth): harden auth gate (OTP->PIN enforcement) + temporary SignOut for QA
e28b943 feat(auth): defer OTP navigation via build-time ref.listen (+state: verificationId/resendToken) [no-format]
53d881d chore(auth): finalize safe OTP navigation and verify-by-SMS linking
adfa96f fix: resolve GoRouter navigation conflicts in auth flow
```

## Environment

| Component | Version |
|-----------|---------|
| Flutter | 3.35.5 (stable) |
| Dart | 3.9.2 |
| Java | OpenJDK 17.0.16+8 |
| Gradle | 8.9 |
| Android Gradle Plugin | 8.6.0 |

## Build Status

| App | Mode | Result | Duration | Artifact |
|-----|------|--------|----------|----------|
| wawapp_driver | Debug | FAILED | 149.8s | N/A |
| wawapp_client | Debug | FAILED | 160.8s | N/A |

## Issues Summary

| Category | Count | Status |
|----------|-------|--------|
| Analyzer Errors | 2 | CRITICAL |
| Analyzer Warnings | 8 | Review |
| Analyzer Info | 40 | Minor |
| Build Failures | 2 | BLOCKER |

### Critical Issues

**BLOCKER: Undefined navigatorKey**
- **Location:** `lib/core/router/app_router.dart` (both apps)
- **Error:** `Undefined name 'navigatorKey'`
- **Impact:** Prevents all builds
- **Files:**
  - `apps/wawapp_client/lib/core/router/app_router.dart:18:19`
  - `apps/wawapp_driver/lib/core/router/app_router.dart:14:19`

### Firebase Configuration

All Firebase configuration files found and verified:
- `apps/wawapp_client/android/app/google-services.json`
- `apps/wawapp_driver/android/app/google-services.json`
- `apps/wawapp_client/lib/firebase_options.dart`
- `apps/wawapp_driver/lib/firebase_options.dart`

## Dependencies

- **wawapp_client:** 41 packages with newer versions (1 discontinued: google_place)
- **wawapp_driver:** 37 packages with newer versions

## Action Required

1. **IMMEDIATE:** Fix navigatorKey export in both apps' main.dart files
2. Review and address 8 analyzer warnings
3. Consider updating discontinued package (google_place)

## Report Artifacts

- `tools/reports/status_2025-11-12T145330.txt`
- `tools/reports/firebase_verify_2025-11-12T145330.log`
- `tools/reports/analyze_2025-11-12T145330.log`
- `tools/reports/build_driver_2025-11-12T145330.log`
- `tools/reports/build_client_2025-11-12T145330.log`
