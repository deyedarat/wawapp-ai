import 'package:flutter/foundation.dart';

/// Base Analytics service - NO-OP implementation (Firebase Analytics removed for Google Play AdServices compliance)
/// for both client and driver apps.
///
/// This abstract class provides:
/// - No-op event logging (all methods do nothing)
/// - Preserved API signatures for backwards compatibility
/// - No Firebase Analytics dependency
///
/// Apps must extend this class and implement:
/// - [setUserType] - Set 'client' or 'driver' user type
/// - App-specific event logging methods (orders, trips, ratings, etc.)
///
/// Example usage:
/// ```dart
/// class ClientAnalyticsService extends BaseAnalyticsService {
///   ClientAnalyticsService._() : super.internal();
///   static final instance = ClientAnalyticsService._();
///
///   @override
///   Future<void> setUserType() async {
///     await setUserProperty(name: 'user_type', value: 'client');
///   }
///
///   // Add client-specific methods...
/// }
/// ```
abstract class BaseAnalyticsService {
  /// Protected constructor for subclasses
  @protected
  BaseAnalyticsService.internal();

  // ===== ABSTRACT METHODS (app-specific) =====

  /// Set user type property ('client' or 'driver')
  ///
  /// Subclasses must implement this to set the appropriate user type
  /// for analytics segmentation.
  Future<void> setUserType();

  // ===== COMMON METHODS (shared infrastructure) =====

  /// Log an error event with error details
  ///
  /// Tracks errors across the app for debugging and monitoring.
  ///
  /// Parameters:
  /// - [errorType]: Type of error (e.g., 'network', 'validation')
  /// - [screen]: Screen where error occurred
  /// - [errorMessage]: Optional error message details
  Future<void> logError({
    required String errorType,
    required String screen,
    String? errorMessage,
  }) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) {
      debugPrint('[Analytics NO-OP] error_occurred: $errorType on $screen');
    }
  }

  /// Log successful authentication completion
  ///
  /// Tracks when users complete authentication flow.
  ///
  /// Parameters:
  /// - [method]: Authentication method used (e.g., 'phone', 'email')
  Future<void> logAuthCompleted({required String method}) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] auth_completed: $method');
  }

  /// Log app opened event
  ///
  /// Tracks app launches for engagement metrics.
  Future<void> logAppOpened() async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] app_opened');
  }

  /// Log screen view for navigation tracking
  ///
  /// Tracks user navigation through the app.
  ///
  /// Parameters:
  /// - [screenName]: Name of the screen being viewed
  /// - [screenClass]: Optional class name of the screen
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] screen_view: $screenName');
  }

  /// Log notification delivered event (foreground)
  ///
  /// Tracks when notifications are delivered to users.
  ///
  /// Parameters:
  /// - [notificationType]: Type of notification (e.g., 'order_update')
  /// - [orderId]: Associated order ID
  Future<void> logNotificationDelivered({
    required String notificationType,
    required String orderId,
  }) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) {
      debugPrint('[Analytics NO-OP] notification_delivered: $notificationType');
    }
  }

  /// Log notification tapped event with app state
  ///
  /// Tracks when users interact with notifications.
  ///
  /// Parameters:
  /// - [notificationType]: Type of notification
  /// - [orderId]: Associated order ID
  /// - [appState]: App state when tapped (e.g., 'background', 'foreground')
  Future<void> logNotificationTapped({
    required String notificationType,
    required String orderId,
    required String appState,
  }) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) {
      debugPrint('[Analytics NO-OP] notification_tapped: $notificationType ($appState)');
    }
  }

  // ===== PROTECTED HELPERS =====

  /// Protected helper for logging custom events with error handling
  ///
  /// Subclasses can use this to log app-specific events with consistent
  /// error handling and debug logging.
  ///
  /// Parameters:
  /// - [name]: Event name
  /// - [parameters]: Event parameters
  @protected
  Future<void> logEvent(String name, Map<String, Object> parameters) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] $name');
  }

  /// Protected helper to set user ID
  ///
  /// Subclasses can use this in their setUserProperties implementations.
  @protected
  Future<void> setUserId(String userId) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] User ID set: $userId');
  }

  /// Protected helper to set user property
  ///
  /// Subclasses can use this in their setUserProperties implementations.
  @protected
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    // No-op: Analytics disabled for AdServices compliance
    if (kDebugMode) debugPrint('[Analytics NO-OP] User property set: $name = $value');
  }
}
