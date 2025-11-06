import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// import 'package:your_app/features/auth/auth_controller.dart';

void main() {
  test('AuthController toggles loading during login', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // final notifier = c.read(authControllerProvider.notifier);
    // expect(c.read(authControllerProvider).loading, false);

    // final fut = notifier.login(phone: '222', pin: '0000');
    // expect(c.read(authControllerProvider).loading, true);
    // await fut;
    // expect(c.read(authControllerProvider).loading, false);
  });
}
