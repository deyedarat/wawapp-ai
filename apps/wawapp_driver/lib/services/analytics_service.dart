import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;

  Future<void> logLoginSuccess(String method) async {
    try {
      await _analytics.logEvent(
        name: 'login_success',
        parameters: {'method': method},
      );
      if (kDebugMode) print('[Analytics] login_success: $method');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging login_success: $e');
    }
  }

  Future<void> logPinCreated() async {
    try {
      await _analytics.logEvent(name: 'pin_created');
      if (kDebugMode) print('[Analytics] pin_created');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging pin_created: $e');
    }
  }

  Future<void> logLogoutClicked() async {
    try {
      await _analytics.logEvent(name: 'logout_clicked');
      if (kDebugMode) print('[Analytics] logout_clicked');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging logout_clicked: $e');
    }
  }

  Future<void> setUserTypeDriver() async {
    try {
      await _analytics.setUserProperty(name: 'user_type', value: 'driver');
      if (kDebugMode) print('[Analytics] user_type set to driver');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user_type: $e');
    }
  }

  Future<void> logOrderAcceptedByDriver({
    required String orderId,
    int? priceAmount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_accepted_by_driver',
        parameters: {
          'order_id': orderId,
          if (priceAmount != null) 'price': priceAmount,
        },
      );
      if (kDebugMode) print('[Analytics] order_accepted_by_driver: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_accepted_by_driver: $e');
    }
  }

  Future<void> logOrderCancelledByDriver({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_cancelled_by_driver',
        parameters: {'order_id': orderId},
      );
      if (kDebugMode) print('[Analytics] order_cancelled_by_driver: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_cancelled_by_driver: $e');
    }
  }

  Future<void> logOrderCompletedByDriver({
    required String orderId,
    int? priceAmount,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_completed_by_driver',
        parameters: {
          'order_id': orderId,
          if (priceAmount != null) 'price': priceAmount,
        },
      );
      if (kDebugMode) print('[Analytics] order_completed_by_driver: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_completed_by_driver: $e');
    }
  }

  Future<void> logDriverWentOnline() async {
    try {
      await _analytics.logEvent(name: 'driver_went_online');
      if (kDebugMode) print('[Analytics] driver_went_online');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging driver_went_online: $e');
    }
  }

  Future<void> logDriverWentOffline() async {
    try {
      await _analytics.logEvent(name: 'driver_went_offline');
      if (kDebugMode) print('[Analytics] driver_went_offline');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging driver_went_offline: $e');
    }
  }

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
      if (kDebugMode) print('[Analytics] error_occurred: $errorType on $screen');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging error_occurred: $e');
    }
  }

  Future<void> logAuthCompleted({required String method}) async {
    try {
      await _analytics.logEvent(
        name: 'auth_completed',
        parameters: {'method': method},
      );
      if (kDebugMode) print('[Analytics] auth_completed: $method');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging auth_completed: $e');
    }
  }

  Future<void> logAppOpened() async {
    try {
      await _analytics.logEvent(name: 'app_opened');
      if (kDebugMode) print('[Analytics] app_opened');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging app_opened: $e');
    }
  }

  /// Set driver-specific user properties
  Future<void> setUserProperties({
    required String userId,
    int? totalTrips,
    double? averageRating,
    bool? isVerified,
    bool? isOnline,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      if (totalTrips != null) {
        await _analytics.setUserProperty(
          name: 'total_trips',
          value: totalTrips.toString(),
        );
      }
      if (averageRating != null) {
        await _analytics.setUserProperty(
          name: 'average_rating',
          value: averageRating.toStringAsFixed(1),
        );
      }
      if (isVerified != null) {
        await _analytics.setUserProperty(
          name: 'is_verified',
          value: isVerified.toString(),
        );
      }
      if (isOnline != null) {
        await _analytics.setUserProperty(
          name: 'is_online',
          value: isOnline.toString(),
        );
      }
      // Always set user type
      await _analytics.setUserProperty(
        name: 'user_type',
        value: 'driver',
      );
      if (kDebugMode) print('[Analytics] User properties set for $userId');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user properties: $e');
    }
  }

  /// Track screen views
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
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging screen_view: $e');
    }
  }

  /// Track when notification is delivered (foreground)
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
      if (kDebugMode)
        print('[Analytics] notification_delivered: $notificationType');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging notification_delivered: $e');
    }
  }

  /// Track when user taps a notification
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
      if (kDebugMode)
        print(
            '[Analytics] notification_tapped: $notificationType ($appState)');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging notification_tapped: $e');
    }
  }
}
