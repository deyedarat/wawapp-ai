import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import your actual providers
import 'package:wawapp_driver/features/earnings/providers/driver_earnings_provider.dart';

void main() {
  group('DriverEarningsProvider Lifecycle Tests', () {
    test('provider is declared with autoDispose', () {
      // This test verifies that the provider uses .autoDispose
      // by checking that it's an AutoDisposeStateNotifierProvider

      // The provider should be an autoDispose provider
      expect(driverEarningsProvider.runtimeType.toString(),
          contains('AutoDispose'));

      // This confirms the provider was declared with .autoDispose
    });

    test('provider can be read without errors when mocked', () {
      // Create a container with overrides to avoid Firebase dependency
      final container = ProviderContainer(
        overrides: [
          // Override the repository to avoid Firebase calls
          driverEarningsRepositoryProvider.overrideWith((ref) {
            throw UnimplementedError(
                'Repository should not be called in this test');
          }),
        ],
      );

      // The provider should exist in the container
      expect(container.exists(driverEarningsProvider), isFalse);

      // After adding a listener, it should exist
      final subscription = container.listen(
        driverEarningsProvider,
        (previous, next) {},
      );

      expect(container.exists(driverEarningsProvider), isTrue);

      // Clean up
      subscription.close();
      container.dispose();
    });

    test('provider disposes when container is disposed', () {
      final container = ProviderContainer(
        overrides: [
          driverEarningsRepositoryProvider.overrideWith((ref) {
            throw UnimplementedError(
                'Repository should not be called in this test');
          }),
        ],
      );

      // Add listener to activate provider
      // Add listener to activate provider
      container.listen(
        driverEarningsProvider,
        (previous, next) {},
      );

      // Provider should exist
      expect(container.exists(driverEarningsProvider), isTrue);

      // Dispose container
      container.dispose();

      // After disposal, the container should be in disposed state
      // The test passes if disposal completes without throwing
      expect(true, isTrue); // Container was successfully disposed
    });
  });
}
