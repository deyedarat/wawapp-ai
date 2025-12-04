import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';

/// Driver-specific Analytics service for ride-hailing driver app.
///
/// Extends [BaseAnalyticsService] with driver-specific event tracking.
class AnalyticsService extends BaseAnalyticsService {
  AnalyticsService._() : super.internal();
  static final instance = AnalyticsService._();

  @override
  Future<void> setUserType() async {
    await setUserProperty(name: 'user_type', value: 'driver');
  }

  Future<void> logLoginSuccess(String method) async {
    await logEvent('login_success', {'method': method});
  }

  Future<void> logPinCreated() async {
    await logEvent('pin_created', {});
  }

  Future<void> logLogoutClicked() async {
    await logEvent('logout_clicked', {});
  }

  Future<void> logOrderAcceptedByDriver({
    required String orderId,
    int? priceAmount,
  }) async {
    await logEvent('order_accepted_by_driver', {
      'order_id': orderId,
      if (priceAmount != null) 'price': priceAmount,
    });
  }

  Future<void> logOrderCancelledByDriver({required String orderId}) async {
    await logEvent('order_cancelled_by_driver', {'order_id': orderId});
  }

  Future<void> logOrderCompletedByDriver({
    required String orderId,
    int? priceAmount,
  }) async {
    await logEvent('order_completed_by_driver', {
      'order_id': orderId,
      if (priceAmount != null) 'price': priceAmount,
    });
  }

  Future<void> logDriverWentOnline() async {
    await logEvent('driver_went_online', {});
  }

  Future<void> logDriverWentOffline() async {
    await logEvent('driver_went_offline', {});
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
      await setUserId(userId);
      if (totalTrips != null) {
        await setUserProperty(
          name: 'total_trips',
          value: totalTrips.toString(),
        );
      }
      if (averageRating != null) {
        await setUserProperty(
          name: 'average_rating',
          value: averageRating.toStringAsFixed(1),
        );
      }
      if (isVerified != null) {
        await setUserProperty(
          name: 'is_verified',
          value: isVerified.toString(),
        );
      }
      if (isOnline != null) {
        await setUserProperty(
          name: 'is_online',
          value: isOnline.toString(),
        );
      }
      // Always set user type
      await setUserProperty(
        name: 'user_type',
        value: 'driver',
      );
      if (kDebugMode) print('[Analytics] User properties set for $userId');
    } on Object catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user properties: $e');
    }
  }
}
