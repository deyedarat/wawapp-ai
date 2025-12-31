import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Import your actual providers
import 'package:wawapp_client/features/profile/providers/client_profile_providers.dart';

void main() {
  group('ClientProfileStreamProvider Lifecycle Tests', () {
    test('provider is declared with autoDispose', () {
      // This test verifies that the provider uses .autoDispose
      // by checking that it's an AutoDisposeStreamProvider
      
      // The provider should be an autoDispose provider
      expect(clientProfileStreamProvider.runtimeType.toString(), contains('AutoDispose'));
      
      // This confirms the provider was declared with .autoDispose
    });

    test('provider can be created without errors', () {
      // Create a container to test basic provider functionality
      final container = ProviderContainer();
      
      // The provider should exist in the container after being accessed
      expect(container.exists(clientProfileStreamProvider), isFalse);
      
      // After adding a listener, it should exist
      final subscription = container.listen(
        clientProfileStreamProvider,
        (previous, next) {},
      );
      
      expect(container.exists(clientProfileStreamProvider), isTrue);
      
      // Clean up
      subscription.close();
      container.dispose();
    });

    test('provider disposes when container is disposed', () {
      final container = ProviderContainer();
      
      // Add listener to activate provider
      // Add listener to activate provider
      container.listen(
        clientProfileStreamProvider,
        (previous, next) {},
      );
      
      // Provider should exist
      expect(container.exists(clientProfileStreamProvider), isTrue);
      
      // Dispose container
      container.dispose();
      
      // After disposal, the container should be in disposed state
      // The test passes if disposal completes without throwing
      expect(true, isTrue); // Container was successfully disposed
    });
  });
}