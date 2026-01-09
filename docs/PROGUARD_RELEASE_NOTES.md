# ProGuard Configuration for WawApp Production Release

**Date**: 2026-01-06
**Release Version**: 1.0.0+1
**Decision**: Use default Android ProGuard rules (no custom rules initially)

---

## Decision Summary

For the initial production release (v1.0.0), we are using **Android's default ProGuard rules** (`proguard-android-optimize.txt`) without custom `proguard-rules.pro` files.

---

## Rationale

### Why Default Rules?

1. **Rapid Production Deployment**: Custom ProGuard rules require extensive testing to ensure no critical classes are stripped. Using defaults allows faster deployment.

2. **Android SDK Protection**: Default rules already protect:
   - Android framework classes
   - Common reflection patterns
   - Essential system services

3. **R8 Compiler Intelligence**: Modern R8 (replacing ProGuard) is smarter about preserving necessary code through static analysis.

4. **Risk Mitigation Strategy**: We will monitor production crashes via Firebase Crashlytics to identify any ProGuard-related issues post-launch.

---

## Current Build Configuration

Both apps have the following enabled in `android/app/build.gradle.kts`:

```kotlin
release {
    signingConfig = signingConfigs.getByName("release")
    isMinifyEnabled = true
    isShrinkResources = true
    proguardFiles(
        getDefaultProguardFile("proguard-android-optimize.txt"),
        "proguard-rules.pro"  // File does not exist - only defaults apply
    )
}
```

---

## Potential Risks

### High-Risk Areas for Code Stripping

| Component | Risk | Monitoring Strategy |
|-----------|------|-------------------- |
| **Riverpod Providers** | Medium | Providers use code generation (`riverpod_generator`) which should be R8-safe, but monitor for state management crashes |
| **GoRouter Routes** | Low-Medium | Route definitions may be stripped if defined dynamically; watch for navigation crashes |
| **Firebase SDK** | Low | Firebase has its own keep rules built-in, but monitor for Auth/Firestore crashes |
| **JSON Serialization** | Medium | If using reflection-based JSON parsing (not code gen), fields may be stripped |
| **Google Maps** | Low | Maps SDK has its own ProGuard rules |
| **FCM** | Low | Firebase Messaging includes keep rules automatically |

---

## When to Add Custom Rules

Add `proguard-rules.pro` files if ANY of the following occur:

### Critical Indicators

1. **Production Crashes**: Firebase Crashlytics shows crashes with messages like:
   - `ClassNotFoundException`
   - `NoSuchMethodException`
   - `FieldNotFoundException`
   - `MissingClass` warnings in R8 output

2. **Runtime Reflection Failures**: App behaves differently in release vs. debug:
   - Authentication flows fail
   - Navigation breaks
   - State management errors
   - API calls fail silently

3. **Third-Party Library Issues**: Libraries that rely on reflection without built-in rules:
   - Custom annotations
   - ORM libraries
   - Dynamic proxy classes

---

## Custom Rules Template (For Future Use)

If custom rules become necessary, create:

### `apps/wawapp_client/android/app/proguard-rules.pro`

```proguard
# Keep Riverpod generated code
-keep class **.*Providers { *; }
-keep class **.*NotifierProviders { *; }

# Keep Firebase model classes
-keepclassmembers class com.wawapp.client.** {
    public <fields>;
    public <methods>;
}

# Keep GoRouter route definitions
-keep class * extends com.example.go_router.** { *; }

# Keep JSON serialization classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep Crashlytics stack traces
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# General reflection protection
-keepattributes Signature
-keepattributes *Annotation*
```

### `apps/wawapp_driver/android/app/proguard-rules.pro`

(Same rules apply for Driver app)

---

## Monitoring Plan

### Phase 1: Post-Launch (First 7 Days)

- [ ] Monitor Firebase Crashlytics daily for ProGuard-related crashes
- [ ] Check error rate for Auth flows (login, logout, PIN)
- [ ] Verify navigation works across all screens
- [ ] Test payment flows (if applicable)

### Phase 2: Optimization (Days 8-30)

- [ ] If crash-free rate < 99.5%, investigate ProGuard issues
- [ ] Add custom rules for any problematic classes
- [ ] Re-test release build with custom rules
- [ ] Deploy hotfix if necessary

### Phase 3: Long-Term Maintenance

- [ ] Review ProGuard warnings in build logs monthly
- [ ] Update rules when adding new dependencies
- [ ] Document any reflection-based code patterns

---

## Build Verification

Before each release, verify:

```bash
# Build release AAB
flutter build appbundle --release

# Check for ProGuard warnings
# Look for "Warning: ..." or "Note: ..." messages in build output

# Verify code shrinking occurred
# AAB size should be significantly smaller than debug APK
```

---

## References

- [Android ProGuard Documentation](https://developer.android.com/build/shrink-code)
- [R8 Optimization Guide](https://developer.android.com/build/r8)
- [Flutter ProGuard Best Practices](https://docs.flutter.dev/deployment/android#shrinking-your-code-with-r8)
- [Firebase ProGuard Rules](https://firebase.google.com/docs/android/setup#proguard)

---

## Revision History

| Date | Version | Change | Author |
|------|---------|--------|--------|
| 2026-01-06 | 1.0 | Initial decision: use default rules | Claude Code |

---

## Contact

For questions about ProGuard configuration, contact the DevOps team or review [CLAUDE.md](../CLAUDE.md) guidelines.
