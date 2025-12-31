class NotificationHelper {
  static String? getRouteFromNotification({
    required String? type,
    required String? role,
  }) {
    if (type == null || role == null) return null;
    if (role != 'driver') return null;

    switch (type) {
      case 'new_order':
        return '/nearby';
      case 'order_cancelled':
        return '/';
      default:
        return null;
    }
  }
}
