class NotificationHelper {
  static String? getRouteFromNotification({
    required String? type,
    required String? role,
  }) {
    if (type == null) return null;

    // Client-specific notifications (role may be null for server-sent)
    switch (type) {
      case 'order_accepted':
      case 'driver_arrived':
      case 'order_completed':
        return '/track';
      case 'order_reassigned':
      case 'driver_accepted':
      case 'driver_on_route':
        return '/track';
      default:
        return null;
    }
  }
}
