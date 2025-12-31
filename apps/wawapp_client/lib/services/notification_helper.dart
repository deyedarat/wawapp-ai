class NotificationHelper {
  static String? getRouteFromNotification({
    required String? type,
    required String? role,
  }) {
    if (type == null || role == null) return null;
    if (role != 'client') return null;

    switch (type) {
      case 'order_accepted':
      case 'driver_arrived':
      case 'order_completed':
        return '/track';
      default:
        return null;
    }
  }
}
