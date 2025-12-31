import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';

/// Client-specific Analytics service for ride-hailing client app.
///
/// Extends [BaseAnalyticsService] with client-specific event tracking.
class AnalyticsService extends BaseAnalyticsService {
  AnalyticsService._() : super.internal();
  static final instance = AnalyticsService._();

  @override
  Future<void> setUserType() async {
    await setUserProperty(name: 'user_type', value: 'client');
  }

  Future<void> logOrderCreated({
    required String orderId,
    required int priceAmount,
    required double distanceKm,
  }) async {
    await logEvent('order_created', {
      'order_id': orderId,
      'price': priceAmount,
      'distance_km': distanceKm,
    });
  }

  Future<void> logOrderCancelledByClient({required String orderId}) async {
    await logEvent('order_cancelled_by_client', {'order_id': orderId});
  }

  Future<void> logTripCompletedViewed({required String orderId}) async {
    await logEvent('order_completed_viewed', {'order_id': orderId});
  }

  Future<void> logDriverRated({
    required String orderId,
    required int rating,
  }) async {
    await logEvent('driver_rated', {
      'order_id': orderId,
      'rating': rating,
    });
  }

  Future<void> logSavedLocationAdded({required String locationLabel}) async {
    await logEvent('saved_location_added', {'label': locationLabel});
  }

  Future<void> logSavedLocationDeleted({required String locationId}) async {
    await logEvent('saved_location_deleted', {'location_id': locationId});
  }

  /// Set user properties for segmentation
  Future<void> setUserProperties({
    required String userId,
    int? totalOrders,
    bool? isVerified,
    String? preferredPaymentMethod,
  }) async {
    try {
      await setUserId(userId);
      if (totalOrders != null) {
        await setUserProperty(
          name: 'total_orders',
          value: totalOrders.toString(),
        );
      }
      if (isVerified != null) {
        await setUserProperty(
          name: 'is_verified',
          value: isVerified.toString(),
        );
      }
      if (preferredPaymentMethod != null) {
        await setUserProperty(
          name: 'preferred_payment_method',
          value: preferredPaymentMethod,
        );
      }
      // Always set user type
      await setUserProperty(
        name: 'user_type',
        value: 'client',
      );
      if (kDebugMode) print('[Analytics] User properties set for $userId');
    } catch (e) {
      if (kDebugMode) print('[Analytics] Error setting user properties: $e');
    }
  }

  /// Track conversion: user rated driver after notification tap
  Future<void> logDriverRatedFromNotification({
    required String orderId,
    required int rating,
  }) async {
    await logEvent('driver_rated_from_notification', {
      'order_id': orderId,
      'rating': rating,
      'conversion': true,
    });
  }
}
