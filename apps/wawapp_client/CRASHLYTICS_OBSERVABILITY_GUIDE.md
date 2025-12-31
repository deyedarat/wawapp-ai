# Crashlytics Observability - Developer Guide

## Overview
The `CrashlyticsObserver` provides standardized crash debugging signals across WawApp Client.

## Automatic Setup
- **App startup**: Standard keys set in `main.dart`
- **Auth changes**: User context set automatically  
- **Route changes**: Route context set automatically
- **Navigation**: Safe navigation logs automatically
- **Maps**: Safe camera operations log automatically

## Manual Usage

### 1. Screen Entry Breadcrumbs
```dart
// At screen initState or build
CrashlyticsObserver.logBreadcrumb('screen_enter', 
  screen: 'HomeScreen',
  route: '/home'
);
```

### 2. Critical Actions
```dart
// Before critical operations
CrashlyticsObserver.logBreadcrumb('order_create_start',
  screen: 'QuoteScreen',
  action: 'create_order',
  extra: {'price': '1500', 'distance': '5.2'}
);
```

### 3. Error Context
```dart
try {
  await criticalOperation();
} catch (e) {
  CrashlyticsObserver.logBreadcrumb('operation_failed',
    action: 'critical_operation',
    extra: {'error': e.toString()}
  );
  rethrow;
}
```

### 4. Custom Navigation (if not using SafeNavigation)
```dart
// Before manual navigation
CrashlyticsObserver.logNavigation(
  action: 'custom_push',
  from: '/current',
  to: '/target',
  canPop: context.canPop(),
  mounted: mounted,
);
```

### 5. Custom Map Operations (if not using SafeCameraHelper)
```dart
// Before map operations
CrashlyticsObserver.logMapOperation(
  action: 'custom_camera',
  mapReady: _mapController != null,
  controllerReady: _isReady,
  screen: 'CustomMapScreen',
);
```

## Standard Keys Available in Crashes

### App Context
- `app_version` - App version (1.0.0)
- `build_number` - Build number (123)
- `build_type` - debug/profile/release

### User Context  
- `user_id` - Firebase user ID
- `role` - client/driver

### Navigation Context
- `current_route` - Current route path
- `screen` - Current screen name
- `nav_action` - Last navigation action
- `can_pop` - Whether context can pop
- `mounted` - Whether widget is mounted

### Map Context
- `map_ready` - Whether map is ready
- `controller_ready` - Whether controller is ready  
- `camera_action` - Last camera action

## Best Practices

### DO
- Use `logBreadcrumb()` for user journey tracking
- Add context before risky operations
- Include relevant extra data
- Use consistent screen/action names

### DON'T  
- Log sensitive user data
- Over-log (max 1 breadcrumb per significant action)
- Use in hot paths (build methods, etc.)
- Log without context

## Example Integration

```dart
class MyScreen extends StatefulWidget {
  @override
  void initState() {
    super.initState();
    
    // Screen entry
    CrashlyticsObserver.logBreadcrumb('screen_enter',
      screen: 'MyScreen',
      route: '/my-screen'
    );
  }
  
  Future<void> _criticalAction() async {
    // Before action
    CrashlyticsObserver.logBreadcrumb('action_start',
      screen: 'MyScreen', 
      action: 'critical_action'
    );
    
    try {
      await performAction();
      
      // Success
      CrashlyticsObserver.logBreadcrumb('action_success',
        screen: 'MyScreen',
        action: 'critical_action'
      );
    } catch (e) {
      // Error context
      CrashlyticsObserver.logBreadcrumb('action_failed',
        screen: 'MyScreen',
        action: 'critical_action',
        extra: {'error': e.toString()}
      );
      rethrow;
    }
  }
}
```

This provides comprehensive crash context while maintaining minimal overhead.