# WawApp Secrets & Configuration Management

## Overview

WawApp uses a multi-layered approach to manage secrets and API keys across development, CI/CD, and production environments.

## 🔐 Secret Categories

### 1. Firebase Configuration Files
**Required for:** All apps (client, driver, admin)

| File | Platform | Location | Source |
|------|----------|----------|--------|
| `google-services.json` | Android | `apps/*/android/app/` | Firebase Console → Project Settings → General → Your Apps |
| `GoogleService-Info.plist` | iOS | `apps/*/ios/Runner/` | Firebase Console → Project Settings → General → Your Apps |
| `firebase_options.dart` | Flutter | `apps/*/lib/` | Generated via `flutterfire configure` |

**Setup:**
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Generate firebase_options.dart for each app
cd apps/wawapp_client
flutterfire configure --project=your-firebase-project-id

cd ../wawapp_driver
flutterfire configure --project=your-firebase-project-id

cd ../wawapp_admin
flutterfire configure --project=your-firebase-project-id
```

### 2. Google Maps API Key
**Required for:** Client app (map features, geocoding, routing)

**Local Development:**
1. Create `apps/wawapp_client/android/app/src/main/res/values/api_keys.xml`:
   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <resources>
       <string name="google_maps_api_key">YOUR_GOOGLE_MAPS_API_KEY</string>
   </resources>
   ```

2. For iOS, add to `apps/wawapp_client/ios/Runner/Info.plist`:
   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_GOOGLE_MAPS_API_KEY</string>
   ```

**Flutter Build Argument:**
```bash
flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

### 3. Android Signing Certificates
**Required for:** Production release builds

**Location:** `apps/*/android/key.properties` (NEVER commit this file)

**Format:**
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=your_key_alias
storeFile=/path/to/your/keystore.jks
```

### 4. Cloud Functions Environment Variables
**Required for:** Firebase Cloud Functions (payment APIs, third-party integrations)

**Setup:**
```bash
cd functions
firebase functions:config:set \
  stripe.secret_key="sk_test_..." \
  sendgrid.api_key="SG...." \
  app.environment="production"
```

**View current config:**
```bash
firebase functions:config:get
```

---

## 🏗️ Environment Setup by Role

### Developer Setup (Local Development)

1. **Clone repository:**
   ```bash
   git clone https://github.com/your-org/wawapp-ai.git
   cd wawapp-ai
   ```

2. **Copy environment templates:**
   ```bash
   # Client app
   cp apps/wawapp_client/.env.example apps/wawapp_client/.env

   # Driver app
   cp apps/wawapp_driver/.env.example apps/wawapp_driver/.env

   # Admin app
   cp apps/wawapp_admin/.env.example apps/wawapp_admin/.env
   ```

3. **Configure Firebase:**
   - Download `google-services.json` from Firebase Console
   - Place in `apps/*/android/app/google-services.json`
   - Run `flutterfire configure` for each app (generates `firebase_options.dart`)

4. **Set Google Maps API Key:**
   - Create `apps/wawapp_client/android/app/src/main/res/values/api_keys.xml` (see template above)
   - Or use build argument: `--dart-define=GOOGLE_MAPS_API_KEY=your_key`

5. **Verify setup:**
   ```bash
   # Run validation script
   ./scripts/validate_secrets.sh
   ```

---

## 🤖 CI/CD Secret Injection

### GitHub Actions

**Required Secrets** (Settings → Secrets and variables → Actions):

| Secret Name | Description | Used By |
|-------------|-------------|---------|
| `FIREBASE_TOKEN` | Firebase CI token (`firebase login:ci`) | All workflows |
| `GOOGLE_MAPS_API_KEY` | Google Maps API key | Client app builds |
| `GOOGLE_SERVICES_JSON_CLIENT` | Base64-encoded `google-services.json` for client app | Client app builds |
| `GOOGLE_SERVICES_JSON_DRIVER` | Base64-encoded `google-services.json` for driver app | Driver app builds |
| `GOOGLE_SERVICES_JSON_ADMIN` | Base64-encoded `google-services.json` for admin app | Admin app builds |
| `ANDROID_KEYSTORE_FILE` | Base64-encoded release keystore | Release builds |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | Release builds |
| `ANDROID_KEY_ALIAS` | Key alias | Release builds |
| `ANDROID_KEY_PASSWORD` | Key password | Release builds |

**Encoding secrets for GitHub:**
```bash
# Encode google-services.json
base64 -i apps/wawapp_client/android/app/google-services.json | pbcopy

# Encode keystore
base64 -i path/to/release.keystore | pbcopy
```

**Example workflow snippet:**
```yaml
- name: Decode google-services.json
  run: |
    echo "${{ secrets.GOOGLE_SERVICES_JSON_CLIENT }}" | base64 --decode > \
      apps/wawapp_client/android/app/google-services.json

- name: Build APK with API key
  run: |
    cd apps/wawapp_client
    flutter build apk \
      --dart-define=GOOGLE_MAPS_API_KEY=${{ secrets.GOOGLE_MAPS_API_KEY }} \
      --release
```

### CodeMagic

**Environment Variables** (App settings → Environment variables):

| Variable | Type | Value |
|----------|------|-------|
| `GOOGLE_MAPS_API_KEY` | Secret | Your Google Maps API key |
| `FIREBASE_PROJECT_ID` | Plain | Your Firebase project ID |
| `CM_KEYSTORE_FILE` | File | Upload your `.jks` file |
| `CM_KEYSTORE_PASSWORD` | Secret | Keystore password |
| `CM_KEY_ALIAS` | Secret | Key alias |
| `CM_KEY_PASSWORD` | Secret | Key password |

**Build script in `codemagic.yaml`:**
```yaml
scripts:
  - name: Inject secrets
    script: |
      echo "$GOOGLE_SERVICES_JSON" > $CM_BUILD_DIR/apps/wawapp_client/android/app/google-services.json

  - name: Build with API key
    script: |
      flutter build apk \
        --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY \
        --release
```

---

## 🚨 Secret Validation & Fail-Fast

### Pre-Build Validation Script

Create `scripts/validate_secrets.sh`:
```bash
#!/bin/bash
set -e

APP_PATH=$1

echo "🔍 Validating secrets for $APP_PATH..."

# Check Firebase config
if [ ! -f "$APP_PATH/lib/firebase_options.dart" ]; then
  echo "❌ ERROR: firebase_options.dart not found!"
  echo "Run: flutterfire configure --project=your-project-id"
  exit 1
fi

# Check google-services.json (Android)
if [ ! -f "$APP_PATH/android/app/google-services.json" ]; then
  echo "❌ ERROR: google-services.json not found!"
  echo "Download from Firebase Console → Project Settings → Your Apps"
  exit 1
fi

# Check Google Maps API key (Client app only)
if [[ "$APP_PATH" == *"wawapp_client"* ]]; then
  if [ ! -f "$APP_PATH/android/app/src/main/res/values/api_keys.xml" ]; then
    echo "⚠️  WARNING: api_keys.xml not found. Maps will not work."
    echo "Create: apps/wawapp_client/android/app/src/main/res/values/api_keys.xml"
    echo "Or use: --dart-define=GOOGLE_MAPS_API_KEY=your_key"
  fi
fi

echo "✅ Secret validation passed!"
```

**Usage in CI:**
```yaml
- name: Validate secrets
  run: |
    chmod +x scripts/validate_secrets.sh
    ./scripts/validate_secrets.sh apps/wawapp_client
    ./scripts/validate_secrets.sh apps/wawapp_driver
```

---

## 📝 Environment Templates

### `.env.example` Files

Located in each app directory (`apps/*/.env.example`):

```env
# Firebase Configuration
# Get these from Firebase Console → Project Settings
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_APP_ID=1:1234567890:android:abcdef1234567890
FIREBASE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Google Maps API Key (Client app only)
# Get from Google Cloud Console → APIs & Services → Credentials
GOOGLE_MAPS_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Environment
ENVIRONMENT=development
DEBUG_MODE=true

# Feature Flags (optional)
ENABLE_ANALYTICS=false
ENABLE_CRASHLYTICS=false
ENABLE_PERFORMANCE_MONITORING=false
```

---

## 🔒 Security Best Practices

### DO ✅
- ✅ Use `.gitignore` to exclude all secret files
- ✅ Store secrets in CI/CD platform's secret manager
- ✅ Rotate API keys every 90 days
- ✅ Use different Firebase projects for dev/staging/prod
- ✅ Enable API key restrictions (HTTP referrers, Android package names)
- ✅ Validate secrets exist before building (fail-fast)
- ✅ Use base64 encoding for binary files in CI (keystores, config files)

### DON'T ❌
- ❌ Commit `.env`, `api_keys.xml`, `key.properties`, or `*.jks` files
- ❌ Share secrets via Slack, email, or unencrypted channels
- ❌ Use production API keys in development/testing
- ❌ Hardcode secrets in source code (e.g., `const apiKey = "abc123"`)
- ❌ Upload keystores to public repositories
- ❌ Use weak keystore passwords (min 12 characters, mixed case + numbers)

---

## 🆘 Troubleshooting

### "Google Maps not loading"
**Cause:** Missing or invalid `GOOGLE_MAPS_API_KEY`

**Fix:**
1. Verify API key is set in `api_keys.xml` or build args
2. Check API key restrictions in Google Cloud Console
3. Enable required APIs: Maps SDK for Android, Maps SDK for iOS, Geocoding API, Directions API

### "Firebase app not configured"
**Cause:** Missing `google-services.json` or `firebase_options.dart`

**Fix:**
1. Download `google-services.json` from Firebase Console
2. Run `flutterfire configure` to regenerate `firebase_options.dart`
3. Rebuild app

### "Build failed: Key hash mismatch"
**Cause:** Using wrong keystore or key alias

**Fix:**
1. Verify `key.properties` has correct `storeFile` path
2. Check `keyAlias` matches keystore
3. Generate new keystore if lost:
   ```bash
   keytool -genkey -v -keystore release.keystore \
     -alias wawapp -keyalg RSA -keysize 2048 -validity 10000
   ```

### "CI build fails: Secret not found"
**Cause:** Secret not configured in CI platform

**Fix:**
1. Go to CI platform → Settings → Secrets
2. Add missing secret (check table above)
3. Ensure secret name matches exactly (case-sensitive)

---

## 🔄 Secret Rotation Policy

| Secret Type | Rotation Frequency | Owner |
|-------------|-------------------|-------|
| Google Maps API Key | Every 90 days | DevOps team |
| Firebase Service Account | Every 180 days | Backend team |
| Android Keystore | Never (unless compromised) | Release manager |
| Cloud Functions secrets | Every 60 days | Backend team |

**Rotation Process:**
1. Generate new secret in provider console
2. Update CI/CD platform secrets
3. Update local `.env` files (notify team via Slack)
4. Revoke old secret after 7-day grace period
5. Document in changelog

---

## 📞 Support

**Questions?** Contact:
- DevOps team: `devops@wawapp.mr`
- Security team: `security@wawapp.mr`
- Slack channel: `#wawapp-infra`

**Emergency secret leak?**
1. Immediately revoke the compromised secret in provider console
2. Notify security team within 15 minutes
3. Generate new secret and update all systems
4. File incident report in `docs/incidents/YYYY-MM-DD-secret-leak.md`
