import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_driver/services/notification_helper.dart';

void main() {
  group('NotificationHelper', () {
    test('returns /nearby for new_order with driver role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'new_order',
        role: 'driver',
      );
      expect(route, '/nearby');
    });

    test('returns / for order_cancelled with driver role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'order_cancelled',
        role: 'driver',
      );
      expect(route, '/');
    });

    test('returns null for unknown type', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'unknown',
        role: 'driver',
      );
      expect(route, null);
    });

    test('returns null for client role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'new_order',
        role: 'client',
      );
      expect(route, null);
    });

    test('returns null when type is null', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: null,
        role: 'driver',
      );
      expect(route, null);
    });

    test('returns null when role is null', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'new_order',
        role: null,
      );
      expect(route, null);
    });
  });
}
