import 'package:flutter/foundation.dart';

class NotificationHelper {
  /// Resolves the notification type from data payload.
  /// Cloud Functions use either 'notificationType' or 'type'.
  static String? resolveType(Map<String, dynamic> data) {
    return data['notificationType'] as String? ?? data['type'] as String?;
  }

  /// Whether this notification type should trigger a full-screen intent.
  static bool isFullScreenType(String? type) {
    return type == 'new_order' ||
        type == 'new_order_nearby' ||
        type == 'unassigned_order_reminder' ||
        type == 'trip_start_reminder';
  }

  static String? getRouteFromNotification({
    required String? type,
    String? role,
  }) {
    if (kDebugMode) {
      print(
          '[NotificationHelper] Processing notification: type=$type, role=$role');
    }

    if (type == null) {
      if (kDebugMode) {
        print('[NotificationHelper] ❌ Missing type, returning null');
      }
      return null;
    }

    String? route;
    switch (type) {
      case 'new_order':
      case 'new_order_nearby':
      case 'unassigned_order_reminder':
        // Full-screen notification route — data passed via GoRouter extra
        route = '/full-screen-notification';
        break;
      case 'trip_start_reminder':
        // Full-screen trip start reminder — data passed via GoRouter extra
        route = '/trip-start-reminder';
        break;
      case 'timeout_expired':
        route = '/nearby';
        break;
      case 'order_cancelled':
      case 'order_cancelled_by_client':
      case 'trip_cancelled_by_client':
      case 'order_expired_driver':
        route = '/';
        break;
      case 'order_accepted':
      case 'acceptance_confirmation':
      case 'trip_started':
      case 'order_started':
        route = '/active-order';
        break;
      case 'order_completed':
        route = '/earnings';
        break;
      case 'payment_received':
        route = '/wallet';
        break;
      default:
        route = null;
    }

    if (kDebugMode) {
      print('[NotificationHelper] ✅ Returning route: $route');
    }

    return route;
  }
}
