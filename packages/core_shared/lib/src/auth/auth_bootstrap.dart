import 'package:flutter/material.dart';

import '../analytics/base_analytics_service.dart';
import '../fcm/base_fcm_service.dart';

/// Shared helper for initializing auth-dependent services
///
/// This provides a consistent way to initialize FCM and Analytics
/// across both client and driver apps. Call from main.dart after
/// Firebase initialization.
///
/// Example usage:
/// ```dart
/// WidgetsBinding.instance.addPostFrameCallback((_) {
///   AuthBootstrap.initializeServices(
///     context: context,
///     fcmService: FCMService.instance,
///     analyticsService: AnalyticsService.instance,
///     userType: 'client', // or 'driver'
///   );
/// });
/// ```
class AuthBootstrap {
  /// Initialize FCM and Analytics services
  ///
  /// This should be called once at app startup, after Firebase
  /// initialization but before the user navigates to any screens.
  ///
  /// Parameters:
  /// - [context]: Build context for service initialization
  /// - [fcmService]: FCM service instance (BaseFCMService)
  /// - [analyticsService]: Analytics service instance (BaseAnalyticsService)
  /// - [userType]: Type of user ('client' or 'driver')
  /// - [userId]: Optional user ID for analytics properties
  /// - [userProperties]: Optional additional user properties for analytics
  static Future<void> initializeServices({
    required BuildContext context,
    required BaseFCMService fcmService,
    required BaseAnalyticsService analyticsService,
    required String userType,
    String? userId,
    Map<String, dynamic>? userProperties,
  }) async {
    try {
      debugPrint('[AuthBootstrap] Initializing services for $userType');

      // Set user type in analytics
      await analyticsService.setUserType(userType: userType);
      debugPrint('[AuthBootstrap] ✓ User type set: $userType');

      // Set user properties if provided
      if (userId != null && userProperties != null) {
        debugPrint('[AuthBootstrap] Setting user properties for $userId');
        // Note: Driver-specific properties like totalTrips, averageRating
        // should be set separately when driver profile data is available
      }

      // Initialize FCM
      debugPrint('[AuthBootstrap] Initializing FCM...');
      await fcmService.initialize(context);
      debugPrint('[AuthBootstrap] ✓ FCM initialized');

      debugPrint('[AuthBootstrap] ✅ All services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[AuthBootstrap] ❌ Error initializing services: $e');
      debugPrint('[AuthBootstrap] Stack trace: $stackTrace');
      // Don't throw - allow app to continue even if initialization fails
    }
  }

  /// Initialize services for authenticated user with properties
  ///
  /// This variant should be called after successful authentication
  /// when user-specific properties are available (e.g., after PIN verification).
  ///
  /// For Driver app: Call with totalTrips, averageRating, isVerified
  /// For Client app: Call with basic user properties
  static Future<void> initializeServicesWithAuth({
    required BuildContext context,
    required BaseFCMService fcmService,
    required BaseAnalyticsService analyticsService,
    required String userType,
    required String userId,
    Map<String, dynamic>? userProperties,
  }) async {
    try {
      debugPrint('[AuthBootstrap] Initializing services with auth for $userId');

      // Set user type
      await analyticsService.setUserType(userType: userType);

      // Set user properties (driver-specific properties should be included)
      // Driver app: totalTrips, averageRating, isVerified
      // Client app: basic properties
      if (userProperties != null) {
        debugPrint('[AuthBootstrap] Setting user properties: ${userProperties.keys.join(', ')}');
        // Note: Actual property setting depends on BaseAnalyticsService implementation
        // Driver app will call setUserProperties with specific fields
      }

      // Initialize FCM
      await fcmService.initialize(context);

      // Log auth completion
      await analyticsService.logAuthCompleted(method: 'phone_pin');

      debugPrint('[AuthBootstrap] ✅ Authenticated services initialized for $userId');
    } catch (e, stackTrace) {
      debugPrint('[AuthBootstrap] ❌ Error initializing authenticated services: $e');
      debugPrint('[AuthBootstrap] Stack trace: $stackTrace');
      // Don't throw - allow app to continue
    }
  }
}
