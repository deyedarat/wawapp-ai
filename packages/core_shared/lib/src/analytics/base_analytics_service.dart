import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Base Analytics service providing common Firebase Analytics infrastructure
/// for both client and driver apps.
///
/// This abstract class handles:
/// - Firebase Analytics initialization and singleton pattern
/// - Common event logging (errors, auth, app lifecycle, notifications)
/// - Screen view tracking
/// - Protected logging helper with error handling
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

  /// Firebase Analytics instance
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

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
    try {
      await _analytics.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_type': errorType,
          'screen': screen,
          if (errorMessage != null) 'error_message': errorMessage,
        },
      );
      if (kDebugMode)
        print('[Analytics] error_occurred: $errorType on $screen');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error logging error_occurred: $e');
    }
  }

  /// Log successful authentication completion
  ///
  /// Tracks when users complete authentication flow.
  ///
  /// Parameters:
  /// - [method]: Authentication method used (e.g., 'phone', 'email')
  Future<void> logAuthCompleted({required String method}) async {
    try {
      await _analytics.logEvent(
        name: 'auth_completed',
        parameters: {'method': method},
      );
      if (kDebugMode) print('[Analytics] auth_completed: $method');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error logging auth_completed: $e');
    }
  }

  /// Log app opened event
  ///
  /// Tracks app launches for engagement metrics.
  Future<void> logAppOpened() async {
    try {
      await _analytics.logEvent(name: 'app_opened');
      if (kDebugMode) print('[Analytics] app_opened');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error logging app_opened: $e');
    }
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
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      if (kDebugMode) print('[Analytics] screen_view: $screenName');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error logging screen_view: $e');
    }
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
    try {
      await _analytics.logEvent(
        name: 'notification_delivered',
        parameters: {
          'notification_type': notificationType,
          'order_id': orderId,
          'app_state': 'foreground',
        },
      );
      if (kDebugMode) {
        print('[Analytics] notification_delivered: $notificationType');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[Analytics] Error logging notification_delivered: $e');
      }
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
    try {
      await _analytics.logEvent(
        name: 'notification_tapped',
        parameters: {
          'notification_type': notificationType,
          'order_id': orderId,
          'app_state': appState,
        },
      );
      if (kDebugMode) {
        print('[Analytics] notification_tapped: $notificationType ($appState)');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[Analytics] Error logging notification_tapped: $e');
      }
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
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (kDebugMode) print('[Analytics] $name');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error logging $name: $e');
    }
  }

  /// Protected helper to set user ID
  ///
  /// Subclasses can use this in their setUserProperties implementations.
  @protected
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      if (kDebugMode) print('[Analytics] User ID set: $userId');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user ID: $e');
    }
  }

  /// Protected helper to set user property
  ///
  /// Subclasses can use this in their setUserProperties implementations.
  @protected
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      if (kDebugMode) print('[Analytics] User property set: $name = $value');
    } on Object catch (e) {
      if (kDebugMode)
        print('[Analytics] Error setting user property $name: $e');
    }
  }
}
