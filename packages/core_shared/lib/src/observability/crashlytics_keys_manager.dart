import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'waw_log.dart';

/// Manages Crashlytics custom keys for Phase 2 observability
/// Ensures all required context is attached to crash reports
class CrashlyticsKeysManager {
  static final CrashlyticsKeysManager _instance = CrashlyticsKeysManager._internal();
  factory CrashlyticsKeysManager() => _instance;
  CrashlyticsKeysManager._internal();

  final _crashlytics = FirebaseCrashlytics.instance;

  // Current state cache to avoid redundant writes
  String? _currentUserId;
  String? _currentUserRole;
  String? _currentAuthState;
  String? _currentActiveOrderId;
  String? _currentActiveOrderStatus;
  String? _currentNetworkType;

  /// Set user context (required for all crash reports)
  Future<void> setUserContext({
    required String? userId,
    required String userRole,
    required String authState,
  }) async {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      if (userId != null) {
        await _crashlytics.setUserIdentifier(userId);
        await _crashlytics.setCustomKey('user_id', userId);
      }
    }

    if (_currentUserRole != userRole) {
      _currentUserRole = userRole;
      await _crashlytics.setCustomKey('user_role', userRole);
    }

    if (_currentAuthState != authState) {
      _currentAuthState = authState;
      await _crashlytics.setCustomKey('auth_state', authState);
    }

    WawLog.d('CrashlyticsKeys', 'User context: role=$userRole, auth=$authState');
  }

  /// Set active order context (null if no active order)
  Future<void> setActiveOrderContext({
    String? activeOrderId,
    String? activeOrderStatus,
  }) async {
    if (_currentActiveOrderId != activeOrderId) {
      _currentActiveOrderId = activeOrderId;
      await _crashlytics.setCustomKey('active_order_id', activeOrderId ?? 'null');
    }

    if (_currentActiveOrderStatus != activeOrderStatus) {
      _currentActiveOrderStatus = activeOrderStatus;
      await _crashlytics.setCustomKey('active_order_status', activeOrderStatus ?? 'null');
    }

    if (activeOrderId != null) {
      WawLog.d('CrashlyticsKeys', 'Active order: $activeOrderId ($activeOrderStatus)');
    }
  }

  /// Set session context (typically set once on app start, updated on network changes)
  Future<void> setSessionContext({
    required String appVersion,
    required String platform,
    required String networkType,
  }) async {
    await _crashlytics.setCustomKey('app_version', appVersion);
    await _crashlytics.setCustomKey('platform', platform);
    
    if (_currentNetworkType != networkType) {
      _currentNetworkType = networkType;
      await _crashlytics.setCustomKey('network_type', networkType);
    }
  }

  /// Update session duration (called periodically or on key events)
  Future<void> updateSessionDuration(Duration duration) async {
    await _crashlytics.setCustomKey('session_duration', duration.inSeconds);
  }

  /// Set failure context before logging non-fatal or when crash might occur
  Future<void> setFailureContext({
    required String failurePoint,
    String? firestoreCollection,
    String? errorCode,
    int? retryCount,
  }) async {
    await _crashlytics.setCustomKey('failure_point', failurePoint);
    
    if (firestoreCollection != null) {
      await _crashlytics.setCustomKey('firestore_collection', firestoreCollection);
    }
    
    if (errorCode != null) {
      await _crashlytics.setCustomKey('error_code', errorCode);
    }
    
    if (retryCount != null) {
      await _crashlytics.setCustomKey('retry_count', retryCount);
    }

    WawLog.d('CrashlyticsKeys', 'Failure context: $failurePoint ${errorCode != null ? "($errorCode)" : ""}');
  }

  /// Record a non-fatal event (Phase 2 requirement for all critical failures)
  Future<void> recordNonFatal({
    required String failurePoint,
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) async {
    // Set failure context
    await setFailureContext(
      failurePoint: failurePoint,
      firestoreCollection: additionalData?['firestore_collection'],
      errorCode: additionalData?['error_code'],
      retryCount: additionalData?['retry_count'],
    );

    // Record the non-fatal error
    final errorObj = error ?? Exception(message);
    final stack = stackTrace ?? StackTrace.current;
    
    await _crashlytics.recordError(
      errorObj,
      stack,
      reason: '[$failurePoint] $message',
      fatal: false,
      information: additionalData?.entries.map((e) => '${e.key}: ${e.value}').toList() ?? [],
    );

    WawLog.e('NonFatal', '[$failurePoint] $message', error, stack);
  }

  /// Clear order context (call when order completes or is cancelled)
  Future<void> clearActiveOrderContext() async {
    await setActiveOrderContext(activeOrderId: null, activeOrderStatus: null);
  }
}

/// Auth state constants
class AuthStateValues {
  static const authenticated = 'authenticated';
  static const anonymous = 'anonymous';
  static const verificationPending = 'verification_pending';
}

/// User role constants
class UserRoleValues {
  static const client = 'client';
  static const driver = 'driver';
}

/// Network type constants
class NetworkTypeValues {
  static const wifi = 'wifi';
  static const cellular = 'cellular';
  static const offline = 'offline';
}

/// Failure point constants (for consistency across the app)
class FailurePoints {
  // Auth
  static const tokenRefresh = 'token_refresh';
  static const phoneVerification = 'phone_verification';
  static const login = 'login';

  // Orders
  static const orderCreation = 'order_creation';
  static const orderAcceptance = 'order_acceptance';
  static const driverAcceptance = 'driver_acceptance';
  static const tripCompletion = 'trip_completion';
  static const paymentProcessing = 'payment_processing';

  // Network & Firestore
  static const firestoreWrite = 'firestore_write';
  static const firestoreRead = 'firestore_read';
  static const firestoreListener = 'firestore_listener';
  static const networkTimeout = 'network_timeout';

  // App Lifecycle
  static const appRestoration = 'app_restoration';
  static const stateDesync = 'state_desync';
}
