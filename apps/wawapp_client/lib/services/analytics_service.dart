import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _analytics = FirebaseAnalytics.instance;

  Future<void> setUserTypeClient() async {
    try {
      await _analytics.setUserProperty(name: 'user_type', value: 'client');
      if (kDebugMode) print('[Analytics] user_type set to client');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user_type: $e');
    }
  }

  Future<void> logOrderCreated({
    required String orderId,
    required int priceAmount,
    required double distanceKm,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'order_created',
        parameters: {
          'order_id': orderId,
          'price': priceAmount,
          'distance_km': distanceKm,
        },
      );
      if (kDebugMode) print('[Analytics] order_created: $orderId');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging order_created: $e');
    }
  }

  Future<void> logOrderCancelledByClient({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_cancelled_by_client',
        parameters: {'order_id': orderId},
      );
      if (kDebugMode) print('[Analytics] order_cancelled_by_client: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_cancelled_by_client: $e');
    }
  }

  Future<void> logTripCompletedViewed({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_completed_viewed',
        parameters: {'order_id': orderId},
      );
      if (kDebugMode) print('[Analytics] order_completed_viewed: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_completed_viewed: $e');
    }
  }

  Future<void> logDriverRated({
    required String orderId,
    required int rating,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'driver_rated',
        parameters: {
          'order_id': orderId,
          'rating': rating,
        },
      );
      if (kDebugMode)
        print('[Analytics] driver_rated: $orderId, rating: $rating');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging driver_rated: $e');
    }
  }

  Future<void> logSavedLocationAdded({required String locationLabel}) async {
    try {
      await _analytics.logEvent(
        name: 'saved_location_added',
        parameters: {'label': locationLabel},
      );
      if (kDebugMode) print('[Analytics] saved_location_added: $locationLabel');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging saved_location_added: $e');
    }
  }

  Future<void> logSavedLocationDeleted({required String locationId}) async {
    try {
      await _analytics.logEvent(
        name: 'saved_location_deleted',
        parameters: {'location_id': locationId},
      );
      if (kDebugMode) print('[Analytics] saved_location_deleted: $locationId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging saved_location_deleted: $e');
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

  /// Set user properties for segmentation
  Future<void> setUserProperties({
    required String userId,
    int? totalOrders,
    bool? isVerified,
    String? preferredPaymentMethod,
  }) async {
    try {
      await _analytics.setUserId(id: userId);
      if (totalOrders != null) {
        await _analytics.setUserProperty(
          name: 'total_orders',
          value: totalOrders.toString(),
        );
      }
      if (isVerified != null) {
        await _analytics.setUserProperty(
          name: 'is_verified',
          value: isVerified.toString(),
        );
      }
      if (preferredPaymentMethod != null) {
        await _analytics.setUserProperty(
          name: 'preferred_payment_method',
          value: preferredPaymentMethod,
        );
      }
      // Always set user type
      await _analytics.setUserProperty(
        name: 'user_type',
        value: 'client',
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

  /// Track conversion: user rated driver after notification tap
  Future<void> logDriverRatedFromNotification({
    required String orderId,
    required int rating,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'driver_rated_from_notification',
        parameters: {
          'order_id': orderId,
          'rating': rating,
          'conversion': true,
        },
      );
      if (kDebugMode)
        print(
            '[Analytics] driver_rated_from_notification: $orderId, rating: $rating');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging driver_rated_from_notification: $e');
    }
  }
}
