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

  Future<void> logOrderCreated({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_created',
        parameters: {'order_id': orderId},
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
      if (kDebugMode) print('[Analytics] Error logging order_cancelled_by_client: $e');
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
      if (kDebugMode) print('[Analytics] Error logging order_completed_viewed: $e');
    }
  }

  Future<void> logDriverRated({required String orderId, required int rating}) async {
    try {
      await _analytics.logEvent(
        name: 'driver_rated',
        parameters: {
          'order_id': orderId,
          'rating': rating,
        },
      );
      if (kDebugMode) print('[Analytics] driver_rated: $orderId, rating: $rating');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error logging driver_rated: $e');
    }
  }
}
