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
}
