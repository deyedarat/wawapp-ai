import 'package:flutter/foundation.dart';

class NotificationHelper {
  static String? getRouteFromNotification({
    required String? type,
    required String? role,
  }) {
    if (kDebugMode) {
      print('[NotificationHelper] Processing notification: type=$type, role=$role');
    }

    if (type == null || role == null) {
      if (kDebugMode) {
        print('[NotificationHelper] ❌ Missing type or role, returning null');
      }
      return null;
    }

    if (role != 'driver') {
      if (kDebugMode) {
        print('[NotificationHelper] ❌ Role is not "driver", returning null');
      }
      return null;
    }

    String? route;
    switch (type) {
      case 'new_order':
        route = '/nearby';
        break;
      case 'order_cancelled':
        route = '/';
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
