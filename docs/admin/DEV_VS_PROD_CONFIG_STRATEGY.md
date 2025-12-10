# Dev vs Production Configuration Strategy

**WawApp Admin Panel**  
**Purpose**: Safely manage development and production environments  
**Status**: Implementation Plan

---

## 🎯 Overview

The WawApp admin panel must support two distinct operational modes:

1. **Development Mode**: Relaxed security for rapid development and testing
2. **Production Mode**: Strict security with custom claims enforcement

**Current Issue:**
- File `admin_auth_service_dev.dart` bypasses `isAdmin` custom claim check
- This is **DANGEROUS** in production (any authenticated user becomes admin)
- Must be disabled/removed before production deployment

---

## 🚨 Critical Security Issue

### Current Dev Auth Service

**File**: `apps/wawapp_admin/lib/services/admin_auth_service_dev.dart`

```dart
/// Check if current user is an admin (DEV MODE - always returns true if authenticated)
Future<bool> isAdmin() async {
  final user = _auth.currentUser;
  return user != null;  // ⚠️ DANGER: No isAdmin claim check!
}
```

**Why this is dangerous:**
- ANY authenticated Firebase user can access admin panel
- No role-based access control
- Financial data exposed to unauthorized users
- Audit trail compromised

**When it's acceptable:**
- Local development
- Testing with emulators
- **NEVER** in production

---

## ✅ Recommended Solution

### Strategy: Compile-Time Environment Selection

Use Dart's `--dart-define` flag to switch between dev and prod configurations at build time.

---

## 📁 File Structure

### Proposed Directory Layout

```
apps/wawapp_admin/lib/
├── config/
│   ├── app_config.dart              # Main config interface
│   ├── dev_config.dart              # Development configuration
│   └── prod_config.dart             # Production configuration
├── services/
│   ├── auth/
│   │   ├── admin_auth_service.dart      # Production auth (with claim check)
│   │   └── admin_auth_service_dev.dart  # Dev auth (bypass - EXISTING)
│   └── ...
└── ...
```

---

## 📝 Implementation Plan

### Step 1: Create Environment Config System

#### File: `lib/config/app_config.dart`

```dart
/// Application configuration base class
abstract class AppConfig {
  /// Environment name (dev, staging, prod)
  String get environment;
  
  /// Whether to use strict admin authentication
  bool get useStrictAuth;
  
  /// Whether to enable debug logging
  bool get enableDebugLogging;
  
  /// Whether to show dev tools
  bool get showDevTools;
  
  /// Firebase project ID
  String get firebaseProjectId;
  
  /// API base URL (if applicable)
  String? get apiBaseUrl;
}

/// Factory to get current config based on environment
class AppConfigFactory {
  static AppConfig getConfig() {
    const environment = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'prod',  // SAFE DEFAULT
    );
    
    switch (environment) {
      case 'dev':
        return DevConfig();
      case 'staging':
        return StagingConfig();
      case 'prod':
      default:
        return ProdConfig();  // Default to production for safety
    }
  }
}
```

#### File: `lib/config/dev_config.dart`

```dart
import 'app_config.dart';

class DevConfig implements AppConfig {
  @override
  String get environment => 'dev';
  
  @override
  bool get useStrictAuth => false;  // Allow dev auth bypass
  
  @override
  bool get enableDebugLogging => true;
  
  @override
  bool get showDevTools => true;
  
  @override
  String get firebaseProjectId => 'wawapp-dev-952d6';
  
  @override
  String? get apiBaseUrl => 'http://localhost:5001';
}
```

#### File: `lib/config/prod_config.dart`

```dart
import 'app_config.dart';

class ProdConfig implements AppConfig {
  @override
  String get environment => 'prod';
  
  @override
  bool get useStrictAuth => true;  // ENFORCE strict auth
  
  @override
  bool get enableDebugLogging => false;
  
  @override
  bool get showDevTools => false;
  
  @override
  String get firebaseProjectId => 'wawapp-952d6';
  
  @override
  String? get apiBaseUrl => null;  // Use Firebase Functions default
}
```

#### File: `lib/config/staging_config.dart` (optional)

```dart
import 'app_config.dart';

class StagingConfig implements AppConfig {
  @override
  String get environment => 'staging';
  
  @override
  bool get useStrictAuth => true;  // Use prod-like auth
  
  @override
  bool get enableDebugLogging => true;  // But keep logging
  
  @override
  bool get showDevTools => true;
  
  @override
  String get firebaseProjectId => 'wawapp-staging-952d6';
  
  @override
  String? get apiBaseUrl => null;
}
```

---

### Step 2: Update Auth Service Selection

#### File: `lib/providers/admin_auth_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../services/auth/admin_auth_service.dart';
import '../services/auth/admin_auth_service_dev.dart';

/// Provider for app configuration
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfigFactory.getConfig();
});

/// Provider for admin authentication service
/// Automatically selects correct service based on environment
final adminAuthServiceProvider = Provider<dynamic>((ref) {
  final config = ref.watch(appConfigProvider);
  
  if (config.useStrictAuth) {
    // PRODUCTION: Use strict auth with isAdmin claim check
    return AdminAuthService();
  } else {
    // DEVELOPMENT: Use bypass auth (no claim check)
    return AdminAuthServiceDev();
  }
});

/// Auth state stream provider
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(adminAuthServiceProvider);
  return authService.authStateChanges;
});
```

---

### Step 3: Update Main Entry Point

#### File: `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/app_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Get configuration
  final config = AppConfigFactory.getConfig();
  
  // Log environment (for verification)
  print('🚀 Starting WawApp Admin Panel');
  print('📍 Environment: ${config.environment}');
  print('🔒 Strict Auth: ${config.useStrictAuth}');
  print('🐛 Debug Logging: ${config.enableDebugLogging}');
  print('🔧 Dev Tools: ${config.showDevTools}');
  
  // CRITICAL: Warn if dev mode in production
  if (!config.useStrictAuth) {
    print('⚠️⚠️⚠️ WARNING: DEV AUTH BYPASS ENABLED ⚠️⚠️⚠️');
    print('⚠️ This should NEVER be used in production!');
    print('⚠️ Any authenticated user can access admin panel!');
  }
  
  runApp(
    ProviderScope(
      child: WawAppAdminApp(config: config),
    ),
  );
}
```

---

## 🚀 Usage

### Development Build

```bash
# Build for development (dev auth bypass enabled)
cd apps/wawapp_admin

flutter run -d chrome --dart-define=ENVIRONMENT=dev

# Or for web release:
flutter build web --release --dart-define=ENVIRONMENT=dev
```

**Expected Output:**
```
🚀 Starting WawApp Admin Panel
📍 Environment: dev
🔒 Strict Auth: false
🐛 Debug Logging: true
🔧 Dev Tools: true
⚠️⚠️⚠️ WARNING: DEV AUTH BYPASS ENABLED ⚠️⚠️⚠️
```

### Staging Build

```bash
# Build for staging (strict auth, test data)
flutter run -d chrome --dart-define=ENVIRONMENT=staging

# Or:
flutter build web --release --dart-define=ENVIRONMENT=staging
```

### Production Build

```bash
# Build for production (strict auth, NO bypass)
flutter run -d chrome --dart-define=ENVIRONMENT=prod

# Or:
flutter build web --release --dart-define=ENVIRONMENT=prod
```

**Expected Output:**
```
🚀 Starting WawApp Admin Panel
📍 Environment: prod
🔒 Strict Auth: true
🐛 Debug Logging: false
🔧 Dev Tools: false
```

**⚠️ CRITICAL**: Production builds MUST NOT show dev auth warning!

---

## 🔒 Security Validation

### Pre-Deployment Checklist

Before deploying to production, verify:

1. **Build Command Uses Correct Flag**
   ```bash
   # ✅ Correct:
   flutter build web --release --dart-define=ENVIRONMENT=prod
   
   # ❌ Wrong (uses default dev):
   flutter build web --release
   ```

2. **Verify Build Output**
   ```bash
   # Check console output for:
   # ✅ "Strict Auth: true"
   # ❌ "WARNING: DEV AUTH BYPASS ENABLED"
   ```

3. **Test Login Flow**
   - Login with non-admin user
   - Should be rejected with "Permission denied"
   - Login with admin user (has `isAdmin: true` claim)
   - Should succeed

4. **Verify Auth Service**
   - Check `admin_auth_providers.dart` is using `AdminAuthService` (not `AdminAuthServiceDev`)
   - Verify `isAdmin()` method checks custom claim

---

## 🎛️ Alternative Approaches

### Option 2: Flutter Flavors

**Pros**: More robust, IDE support  
**Cons**: More complex setup, requires multiple build configurations

```bash
# Create flavors in pubspec.yaml (not currently used)
flutter:
  flavors:
    dev:
      identifier: mr.wawapp.admin.dev
    prod:
      identifier: mr.wawapp.admin

# Build with flavor
flutter build web --flavor dev
flutter build web --flavor prod
```

### Option 3: Environment Files

**Pros**: Easy to manage, clear separation  
**Cons**: Risk of wrong file being deployed

```
lib/config/
├── env_dev.dart
├── env_staging.dart
└── env_prod.dart

# Manual import:
import 'config/env_prod.dart' as config;
```

**Not Recommended**: Too easy to deploy wrong file

---

## 📊 Comparison Matrix

| Feature | Dev Mode | Staging Mode | Prod Mode |
|---------|----------|--------------|-----------|
| **Auth Bypass** | ✅ Enabled | ❌ Disabled | ❌ Disabled |
| **Custom Claims** | ❌ Not checked | ✅ Checked | ✅ Checked |
| **Debug Logging** | ✅ Enabled | ✅ Enabled | ❌ Disabled |
| **Dev Tools** | ✅ Shown | ✅ Shown | ❌ Hidden |
| **Error Details** | ✅ Full stack | ✅ Full stack | ❌ User-friendly |
| **Test Data** | ✅ Allowed | ✅ Allowed | ❌ Real only |
| **Firebase Project** | dev | staging | prod |
| **Monitoring** | ❌ Optional | ✅ Recommended | ✅ Required |

---

## 🧪 Testing Strategy

### Test Each Environment

#### Development Environment
```bash
# Build dev
flutter build web --dart-define=ENVIRONMENT=dev

# Test cases:
# 1. Any authenticated user can access admin panel ✅
# 2. No isAdmin claim required ✅
# 3. Dev tools visible ✅
# 4. Debug logging in console ✅
```

#### Production Environment
```bash
# Build prod
flutter build web --dart-define=ENVIRONMENT=prod

# Test cases:
# 1. Non-admin user CANNOT access admin panel ✅
# 2. Admin user (with claim) CAN access ✅
# 3. Dev tools hidden ✅
# 4. No debug logging ✅
# 5. No dev auth warning ✅
```

---

## 📋 Migration Steps

### To Implement This Strategy

1. **Create config files** (see File Structure above)
2. **Update `admin_auth_providers.dart`** to use config
3. **Update `main.dart`** to initialize config
4. **Update build scripts** to include `--dart-define`
5. **Update CI/CD pipelines** with correct flags
6. **Update deployment documentation**
7. **Test all environments thoroughly**
8. **Deploy to staging first**, then prod

### Estimated Time: 2-4 hours

---

## ⚠️ CRITICAL WARNINGS

### NEVER Deploy Dev Mode to Production

**Consequences:**
- ❌ Any user can become admin
- ❌ Financial data exposed
- ❌ Audit trail compromised
- ❌ Legal liability
- ❌ Data breach risk

**Protection:**
1. Default to production mode if no flag specified
2. Show prominent warning in console if dev mode
3. Add assertion in production build
4. Automated checks in CI/CD
5. Manual verification before deployment

### Verification Before Prod Deployment

**Required Checks:**
```dart
// Add to main.dart for extra safety:
void main() {
  // ... existing code ...
  
  final config = AppConfigFactory.getConfig();
  
  // CRITICAL: Fail fast if dev mode in web release
  if (!config.useStrictAuth && kReleaseMode) {
    throw Exception(
      '🚨 CRITICAL: Dev auth bypass is enabled in release mode! '
      'This is a security violation. Build must use: '
      '--dart-define=ENVIRONMENT=prod'
    );
  }
  
  // ... rest of main ...
}
```

---

## 📚 Additional Resources

### Flutter Build Configurations
- [Flutter Build Modes](https://docs.flutter.dev/testing/build-modes)
- [Dart Define](https://docs.flutter.dev/deployment/flavors#using---dart-define)
- [Environment Variables](https://pub.dev/packages/flutter_dotenv)

### Security Best Practices
- [Firebase Security Rules](https://firebase.google.com/docs/rules)
- [Custom Claims](https://firebase.google.com/docs/auth/admin/custom-claims)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

## ✅ Acceptance Criteria

Before marking this strategy as "Implemented":

- [ ] All config files created
- [ ] Auth provider updated to use config
- [ ] Main.dart updated with environment logging
- [ ] Dev build tested with bypass enabled
- [ ] Prod build tested with strict auth
- [ ] Non-admin user rejected in prod
- [ ] Admin user (with claim) succeeds in prod
- [ ] No dev warnings in prod build console
- [ ] Deployment scripts updated with correct flags
- [ ] Documentation updated
- [ ] Team trained on new process

---

**Status**: 📝 IMPLEMENTATION PLAN  
**Priority**: 🔴 CRITICAL - Must be implemented before production deployment  
**Estimated Effort**: 2-4 hours  
**Risk if not implemented**: 🚨 SEVERE - Security breach, unauthorized admin access

---

**Document Version**: 1.0  
**Last Updated**: December 2025  
**Author**: GenSpark AI Developer

