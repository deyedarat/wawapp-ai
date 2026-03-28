import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wawapp_client/features/map/pick_route_controller.dart';
import 'package:wawapp_client/utils/geocoding_helper.dart';

void main() {
  group('mapsApiKeyProvider', () {
    test('returns empty string when MAPS_API_KEY not set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = container.read(mapsApiKeyProvider);
      expect(key, isEmpty);
    });
  });

  group('RoutePickerNotifier', () {
    test('can be created with override', () {
      final container = ProviderContainer(
        overrides: [
          mapsApiKeyProvider.overrideWithValue('TEST_KEY'),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(routePickerProvider.notifier);
      expect(notifier.apiKey, 'TEST_KEY');
    });

    test('asserts when apiKey is empty in debug mode', () {
      expect(
        () => RoutePickerNotifier(''),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('GeocodingHelper', () {
    test('can be constructed with empty key', () {
      final helper = GeocodingHelper('');
      expect(helper.apiKey, isEmpty);
    });

    test('reverseGeocode returns error message when apiKey is empty', () async {
      final helper = GeocodingHelper('');
      final result = await helper.reverseGeocode(
        const LatLng(0, 0),
      );
      expect(result, contains('مفتاح'));
    });
  });
}
