# WawApp Monorepo

## Structure
```
root/
├── apps/
│   ├── wawapp_client/     # Flutter client app
│   └── wawapp_driver/     # Flutter driver app
├── functions/             # Firebase Cloud Functions v2 (Node 18+)
├── admin_web/            # Next.js/React admin panel
└── docs/                 # Documentation
```

## Development

### Prerequisites
- Flutter 3.35.5+
- Node.js 18+
- JDK 17
- Android Studio with AGP 8.7.0+

### Scripts
```bash
# Flutter apps
cd apps/wawapp_client && flutter run
cd apps/wawapp_driver && flutter run

# Firebase functions
cd functions && npm run serve

# Admin web
cd admin_web && npm run dev
```

### Setup

#### Quick Start
1. **Install dependencies:**
   ```bash
   # Flutter apps
   cd apps/wawapp_client && flutter pub get
   cd ../wawapp_driver && flutter pub get
   cd ../wawapp_admin && flutter pub get

   # Firebase functions
   cd ../../functions && npm install
   ```

2. **Configure secrets and API keys:**
   ```bash
   # Copy environment templates
   cp apps/wawapp_client/.env.example apps/wawapp_client/.env
   cp apps/wawapp_driver/.env.example apps/wawapp_driver/.env
   cp apps/wawapp_admin/.env.example apps/wawapp_admin/.env

   # Edit .env files and add your API keys
   # See SECRETS_MANAGEMENT.md for detailed instructions
   ```

3. **Set up Firebase:**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli

   # Configure Firebase for each app
   cd apps/wawapp_client
   flutterfire configure --project=your-firebase-project-id

   cd ../wawapp_driver
   flutterfire configure --project=your-firebase-project-id

   cd ../wawapp_admin
   flutterfire configure --project=your-firebase-project-id
   ```

4. **Download Firebase configuration files:**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Select your project → Project Settings
   - Download `google-services.json` for Android apps
   - Place in `apps/*/android/app/google-services.json`
   - Download `GoogleService-Info.plist` for iOS apps
   - Place in `apps/*/ios/Runner/GoogleService-Info.plist`

5. **Configure Google Maps API Key (Client app only):**
   ```bash
   # Create api_keys.xml
   mkdir -p apps/wawapp_client/android/app/src/main/res/values
   cat > apps/wawapp_client/android/app/src/main/res/values/api_keys.xml << 'EOF'
   <?xml version="1.0" encoding="utf-8"?>
   <resources>
       <string name="google_maps_api_key">YOUR_ACTUAL_GOOGLE_MAPS_API_KEY</string>
   </resources>
   EOF
   ```

6. **Validate your setup:**
   ```bash
   # Run validation script
   chmod +x scripts/validate_secrets.sh
   ./scripts/validate_secrets.sh apps/wawapp_client
   ./scripts/validate_secrets.sh apps/wawapp_driver
   ./scripts/validate_secrets.sh apps/wawapp_admin
   ```

7. **Run the apps:**
   ```bash
   # Client app
   cd apps/wawapp_client
   flutter run

   # Driver app
   cd apps/wawapp_driver
   flutter run
   ```

#### Important Security Notes
- **NEVER commit** `.env`, `api_keys.xml`, `key.properties`, or `*.jks` files
- See [SECRETS_MANAGEMENT.md](SECRETS_MANAGEMENT.md) for complete documentation
- For CI/CD setup, see the "CI/CD Secret Injection" section in SECRETS_MANAGEMENT.md