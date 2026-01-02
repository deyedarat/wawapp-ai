# App Configuration Service - Implementation Guide

## Overview
This implementation provides a centralized app configuration system that fetches settings from the backend API and controls app behavior based on maintenance status, version requirements, and force update flags.

## Architecture

### Clean Architecture Layers

```
lib/
├── core/
│   ├── models/
│   │   └── app_config.dart         # Data model for config response
│   └── utils/
│       └── version_utils.dart      # Version comparison utilities
├── services/
│   ├── config_service.dart         # Service layer for API calls
│   └── config_provider.dart        # Riverpod providers
└── features/
    └── config/
        ├── config_gate.dart        # Main config checking widget
        ├── maintenance_screen.dart # UI for maintenance mode
        └── update_required_screen.dart # UI for force updates
```

## Components

### 1. AppConfig Model (`core/models/app_config.dart`)
- **Purpose**: Parse and represent backend configuration
- **Fields**:
  - `minClientVersion`: Minimum required app version
  - `maintenance`: Boolean flag for maintenance mode
  - `forceUpdate`: Boolean flag for forced updates
  - `supportWhatsApp`: Support WhatsApp number
  - `message`: Optional custom message
  - `serverTime`: Server timestamp

### 2. ConfigService (`services/config_service.dart`)
- **Purpose**: Fetch configuration from backend API
- **Features**:
  - Singleton pattern
  - Caching with 5-minute timeout
  - Error handling
  - Timeout protection (10 seconds)
- **Base URL**: `http://77.42.76.36`
- **Endpoint**: `/api/public/config`

### 3. ConfigProvider (`services/config_provider.dart`)
- **Purpose**: Riverpod providers for state management
- **Providers**:
  - `configServiceProvider`: Singleton service instance
  - `appConfigProvider`: FutureProvider for async config fetching
  - `cachedConfigProvider`: Synchronous cached config access

### 4. VersionUtils (`core/utils/version_utils.dart`)
- **Purpose**: Semantic version comparison
- **Key Methods**:
  - `compareVersions(v1, v2)`: Compare two version strings
  - `isUpdateRequired(current, min)`: Check if update needed
  - `extractVersion(pubspecVersion)`: Extract version from pubspec format

### 5. ConfigGate (`features/config/config_gate.dart`)
- **Purpose**: Main integration widget that wraps the app
- **Behavior**:
  1. Fetches config on app start
  2. Shows loading screen while fetching
  3. Checks conditions in priority order:
     - Maintenance mode → Show MaintenanceScreen
     - Force update → Show UpdateRequiredScreen
     - Version check → Show UpdateRequiredScreen if needed
     - All passed → Show normal app
  4. On error → Allow app to continue (fail-safe)

### 6. MaintenanceScreen (`features/config/maintenance_screen.dart`)
- **Purpose**: Block app access during maintenance
- **Features**:
  - Displays maintenance message
  - Shows support WhatsApp button
  - Full-screen blocking UI
  - Arabic text support

### 7. UpdateRequiredScreen (`features/config/update_required_screen.dart`)
- **Purpose**: Require users to update the app
- **Features**:
  - Shows current vs required version
  - "Update Now" button (opens app store)
  - Optional "Not Now" button (only if not forced)
  - Platform-specific store links (Android/iOS)
  - Arabic text support

## Integration

### Main App Integration (`main.dart`)
The ConfigGate wraps the MaterialApp.router:

```dart
import 'features/config/config_gate.dart';

@override
Widget build(BuildContext context) {
  final router = ref.watch(appRouterProvider);
  
  return ConfigGate(
    child: MaterialApp.router(
      // ... your MaterialApp configuration
    ),
  );
}
```

## Behavior Flow

### Priority Order
1. **Maintenance Mode** (Highest Priority)
   - If `maintenance == true`
   - Shows MaintenanceScreen
   - Blocks all app access
   
2. **Force Update**
   - If `forceUpdate == true`
   - Shows UpdateRequiredScreen with forced flag
   - User cannot skip
   
3. **Version Check**
   - If `currentVersion < minClientVersion`
   - Shows UpdateRequiredScreen
   - User cannot skip

4. **Normal Operation**
   - All checks passed
   - App functions normally

### Error Handling
- Network errors: App continues normally (fail-safe)
- Parse errors: App continues normally
- Timeout: App continues normally
- This ensures network issues don't block the app

## Usage Examples

### Testing Maintenance Mode
Backend sets:
```json
{
  "maintenance": true,
  "message": "نحن نقوم بصيانة مجدولة. سنعود قريباً!"
}
```

### Testing Force Update
Backend sets:
```json
{
  "forceUpdate": true,
  "minClientVersion": "1.0.5",
  "message": "يرجى تحديث التطبيق للحصول على التحسينات الجديدة"
}
```

### Testing Version Check
Backend sets:
```json
{
  "minClientVersion": "1.1.0",
  "maintenance": false,
  "forceUpdate": false
}
```
If app version is 1.0.1, UpdateRequiredScreen will show.

## Configuration

### Update Store URLs
Edit `update_required_screen.dart` to set your actual store URLs:

**Android:**
```dart
storeUrl = Uri.parse(
  'https://play.google.com/store/apps/details?id=YOUR_PACKAGE_NAME',
);
```

**iOS:**
```dart
storeUrl = Uri.parse(
  'https://apps.apple.com/app/idYOUR_APP_ID',
);
```

### Change Base URL
Edit `config_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_BACKEND_URL';
```

### Adjust Cache Duration
Edit `config_service.dart`:
```dart
static const Duration cacheTimeout = Duration(minutes: 5);
```

## Dependencies Added

### pubspec.yaml
```yaml
dependencies:
  url_launcher: ^6.2.5  # For opening app stores and WhatsApp
  # Already present:
  # http: ^0.13.6
  # package_info_plus: ^8.1.2
  # flutter_riverpod: ^2.4.9
```

## Files Created

1. `/lib/core/models/app_config.dart` - Config model
2. `/lib/core/utils/version_utils.dart` - Version utilities
3. `/lib/services/config_service.dart` - API service
4. `/lib/services/config_provider.dart` - Riverpod providers
5. `/lib/features/config/config_gate.dart` - Main integration widget
6. `/lib/features/config/maintenance_screen.dart` - Maintenance UI
7. `/lib/features/config/update_required_screen.dart` - Update UI

## Files Modified

1. `/pubspec.yaml` - Added url_launcher dependency
2. `/lib/main.dart` - Wrapped app with ConfigGate

## Testing Checklist

- [ ] Config fetches successfully on app start
- [ ] Maintenance mode blocks app access
- [ ] Force update shows update screen
- [ ] Version check works correctly
- [ ] Update button opens correct store
- [ ] WhatsApp support button works
- [ ] Network errors don't block app
- [ ] Loading screen shows during fetch
- [ ] Cache works (no repeated calls)
- [ ] Arabic text displays correctly

## Backend API Contract

### Endpoint
```
GET /api/public/config
```

### Response
```json
{
  "minClientVersion": "1.0.5",
  "maintenance": false,
  "forceUpdate": false,
  "supportWhatsApp": "+222XXXXXXXX",
  "message": null,
  "serverTime": "2026-01-02T10:55:02.215Z"
}
```

### Fields
- `minClientVersion` (string): Minimum required version (semantic versioning)
- `maintenance` (boolean): Enable/disable maintenance mode
- `forceUpdate` (boolean): Force all users to update
- `supportWhatsApp` (string): Support WhatsApp number with country code
- `message` (string|null): Custom message to display
- `serverTime` (string): ISO 8601 timestamp

## Best Practices

1. **Backend Control**: All behavior is controlled from backend
2. **Fail-Safe**: Network errors don't block app access
3. **Priority Order**: Maintenance > Force Update > Version Check
4. **Caching**: Reduces unnecessary API calls
5. **User Experience**: Clear messages in Arabic
6. **Error Handling**: Comprehensive error catching
7. **Timeout**: 10-second timeout prevents hanging
8. **Clean Architecture**: Separation of concerns

## Troubleshooting

### Config Not Fetching
- Check network connectivity
- Verify base URL is correct
- Check backend is running
- Look for errors in console

### Version Check Not Working
- Verify version format in pubspec.yaml
- Check minClientVersion format in backend
- Test version comparison logic

### Store Links Not Working
- Verify package name (Android)
- Verify App Store ID (iOS)
- Check url_launcher permissions

### Arabic Text Issues
- Ensure app locale is set to 'ar'
- Check font supports Arabic
- Verify text direction (RTL)
