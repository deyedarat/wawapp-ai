import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wawapp_client/main.dart' as app;
import 'package:wawapp_client/features/track/data/orders_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth and Order Integration Tests', () {
    testWidgets('Boot app, verify auth, and test order creation',
        (tester) async {
      // 1) Boot the app
      app.main();
      await tester.pumpAndSettle();

      // 2) Wait for non-null user via userChanges
      await FirebaseAuth.instance.userChanges().firstWhere((u) => u != null);

      // Assert currentUser is not null and print UID
      expect(FirebaseAuth.instance.currentUser, isNotNull);
      final uid = FirebaseAuth.instance.currentUser!.uid;
      print('Integration test - Auth UID: $uid');

      // 3) Test order creation with unified schema
      final repository = OrdersRepository();

      // This should NOT throw "Not signed in" error
      expect(() async {
        final orderId = await repository.createOrder(
          ownerId: uid,
          pickup: {'lat': 18.0783, 'lng': -15.9744, 'label': 'Pickup A'},
          dropoff: {'lat': 18.0969, 'lng': -15.9497, 'label': 'Dropoff B'},
          distanceKm: 2.5,
          price: 100,
          status: 'matching',
        );
        print('Integration test - Order created: $orderId');
      }, returnsNormally);
    });
  });
}
