import 'package:flutter_test/flutter_test.dart';
import 'package:core_shared/core_shared.dart';

void main() {
  group('OrderStatus', () {
    test('fromFirestore should parse valid values', () {
      expect(OrderStatus.fromFirestore('requested'), OrderStatus.requested);
      expect(OrderStatus.fromFirestore('matching'), OrderStatus.assigning);
      expect(OrderStatus.fromFirestore('assigning'), OrderStatus.assigning);
      expect(OrderStatus.fromFirestore('accepted'), OrderStatus.accepted);
      expect(OrderStatus.fromFirestore('onRoute'), OrderStatus.onRoute);
      expect(OrderStatus.fromFirestore('completed'), OrderStatus.completed);
    });

    test('fromFirestore should handle legacy values', () {
      expect(OrderStatus.fromFirestore('assigned'), OrderStatus.accepted);
      expect(OrderStatus.fromFirestore('enRoute'), OrderStatus.onRoute);
      expect(OrderStatus.fromFirestore('delivered'), OrderStatus.completed);
      expect(OrderStatus.fromFirestore('cancelled'),
          OrderStatus.cancelledByDriver);
    });

    test('toFirestore should return correct values', () {
      expect(OrderStatus.requested.toFirestore(), 'requested');
      expect(OrderStatus.assigning.toFirestore(), 'matching');
      expect(OrderStatus.accepted.toFirestore(), 'accepted');
      expect(OrderStatus.onRoute.toFirestore(), 'onRoute');
      expect(OrderStatus.completed.toFirestore(), 'completed');
    });

    test('toArabicLabel should return correct Arabic text', () {
      expect(OrderStatus.requested.toArabicLabel(), 'قيد الإنشاء');
      expect(OrderStatus.assigning.toArabicLabel(), 'جارِ التعيين');
      expect(OrderStatus.accepted.toArabicLabel(), 'تم التعيين');
      expect(OrderStatus.onRoute.toArabicLabel(), 'في الطريق');
      expect(OrderStatus.completed.toArabicLabel(), 'تم');
    });

    test('driver action helpers should work correctly', () {
      expect(OrderStatus.accepted.canDriverStartTrip, true);
      expect(OrderStatus.onRoute.canDriverStartTrip, false);

      expect(OrderStatus.onRoute.canDriverCompleteTrip, true);
      expect(OrderStatus.accepted.canDriverCompleteTrip, false);

      expect(OrderStatus.accepted.canDriverCancel, true);
      expect(OrderStatus.onRoute.canDriverCancel, true);
      expect(OrderStatus.completed.canDriverCancel, false);
    });

    test('canTransitionTo should enforce valid transitions', () {
      expect(
          OrderStatus.requested.canTransitionTo(OrderStatus.assigning), true);
      expect(OrderStatus.assigning.canTransitionTo(OrderStatus.accepted), true);
      expect(OrderStatus.accepted.canTransitionTo(OrderStatus.onRoute), true);
      expect(OrderStatus.onRoute.canTransitionTo(OrderStatus.completed), true);

      // Invalid transitions
      expect(OrderStatus.completed.canTransitionTo(OrderStatus.onRoute), false);
      expect(
          OrderStatus.requested.canTransitionTo(OrderStatus.completed), false);
    });

    test('createTransitionUpdate should include correct fields', () {
      final update =
          OrderStatus.accepted.createTransitionUpdate(driverId: 'driver123');
      expect(update['status'], 'accepted');
      expect(update['driverId'], 'driver123');
      expect(update.containsKey('updatedAt'), true);

      final updateWithoutDriver = OrderStatus.onRoute.createTransitionUpdate();
      expect(updateWithoutDriver['status'], 'onRoute');
      expect(updateWithoutDriver.containsKey('driverId'), false);
    });
  });
}
