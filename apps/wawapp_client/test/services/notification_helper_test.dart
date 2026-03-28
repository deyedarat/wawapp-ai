import 'package:flutter_test/flutter_test.dart';
import 'package:wawapp_client/services/notification_helper.dart';

void main() {
  group('NotificationHelper', () {
    test('returns /track for order_accepted with client role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'order_accepted',
        role: 'client',
      );
      expect(route, '/track');
    });

    test('returns /track for driver_arrived with client role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'driver_arrived',
        role: 'client',
      );
      expect(route, '/track');
    });

    test('returns /track for order_completed with client role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'order_completed',
        role: 'client',
      );
      expect(route, '/track');
    });

    test('returns null for unknown type', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'unknown',
        role: 'client',
      );
      expect(route, null);
    });

    test('returns null for driver role', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'order_accepted',
        role: 'driver',
      );
      expect(route, null);
    });

    test('returns null when type is null', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: null,
        role: 'client',
      );
      expect(route, null);
    });

    test('returns null when role is null', () {
      final route = NotificationHelper.getRouteFromNotification(
        type: 'order_accepted',
        role: null,
      );
      expect(route, null);
    });
  });
}
