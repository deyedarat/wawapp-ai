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

  Future<void> logOrderAcceptedByDriver({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_accepted_by_driver',
        parameters: {'order_id': orderId},
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

  Future<void> logOrderCompletedByDriver({required String orderId}) async {
    try {
      await _analytics.logEvent(
        name: 'order_completed_by_driver',
        parameters: {'order_id': orderId},
      );
      if (kDebugMode) print('[Analytics] order_completed_by_driver: $orderId');
    } catch (e) {
      if (kDebugMode)
        print('[Analytics] Error logging order_completed_by_driver: $e');
    }
  }
}
