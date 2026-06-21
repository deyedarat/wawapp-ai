import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// Uses the Google Maps JavaScript Geocoder (already loaded in the page)
/// to reverse-geocode a lat/lng into a human-readable address.
///
/// This works with referer-restricted API keys because the request
/// originates from the browser (not server-side HTTP).
class WebGeocoder {
  static const String _tag = 'WebGeocoder';

  /// Reverse geocode lat/lng using Google Maps JS Geocoder.
  /// Returns the best short name (POI name if available, else short address).
  /// Falls back to null if Google Maps JS is not available.
  static Future<String?> reverseGeocode(double lat, double lng) async {
    if (!kIsWeb) return null;

    try {
      // First try Places findPlaceFromQuery with location bias to get POI name
      final placeName = await _findNearbyPlaceName(lat, lng);
      if (placeName != null) {
        debugPrint('[$_tag] Found place via PlacesService: $placeName');
        return placeName;
      }

      // Fallback to Geocoder
      return await _geocoderReverse(lat, lng);
    } catch (e) {
      debugPrint('[$_tag] Error: $e');
      return null;
    }
  }

  /// Use Google Maps Places (New) searchNearby to find the POI name
  static Future<String?> _findNearbyPlaceName(double lat, double lng) async {
    try {
      final google = globalContext.getProperty('google'.toJS) as JSObject?;
      if (google == null || google.isUndefinedOrNull) return null;
      final maps = google.getProperty('maps'.toJS) as JSObject?;
      if (maps == null || maps.isUndefinedOrNull) return null;
      final places = maps.getProperty('places'.toJS) as JSObject?;
      if (places == null || places.isUndefinedOrNull) return null;

      // Use new Place.searchNearby API
      final placeClass = places.getProperty('Place'.toJS) as JSObject?;
      if (placeClass == null || placeClass.isUndefinedOrNull) {
        debugPrint('[$_tag] Place class not available');
        return null;
      }

      // Build the request for searchNearby
      // { fields: ['displayName'], locationRestriction: { center: {lat, lng}, radius: 50 } }
      final center = JSObject();
      center.setProperty('lat'.toJS, lat.toJS);
      center.setProperty('lng'.toJS, lng.toJS);

      final locationRestriction = JSObject();
      locationRestriction.setProperty('center'.toJS, center);
      locationRestriction.setProperty('radius'.toJS, 50.0.toJS);

      final request = JSObject();
      request.setProperty('fields'.toJS, ['displayName', 'location'].jsify());
      request.setProperty('locationRestriction'.toJS, locationRestriction);
      request.setProperty('maxResultCount'.toJS, 1.toJS);
      request.setProperty('language'.toJS, 'ar'.toJS);

      // Call Place.searchNearby(request) — returns a Promise
      final searchNearbyFn = placeClass.getProperty('searchNearby'.toJS);
      if (searchNearbyFn == null || searchNearbyFn.isUndefinedOrNull) {
        debugPrint('[$_tag] searchNearby not available');
        return null;
      }

      final promise = (placeClass as JSObject).callMethod('searchNearby'.toJS, request) as JSObject;

      // Await the JS Promise
      final completer = Completer<String?>();

      final thenFn = promise.getProperty('then'.toJS) as JSFunction;
      thenFn.callAsFunction(
        promise,
        ((JSObject result) {
          try {
            final placesResult = result.getProperty('places'.toJS) as JSArray?;
            if (placesResult == null || placesResult.toDart.isEmpty) {
              completer.complete(null);
              return;
            }
            final firstPlace = placesResult.toDart[0] as JSObject;
            final displayName = firstPlace.getProperty('displayName'.toJS) as JSString?;
            final name = displayName?.toDart;
            debugPrint('[$_tag] Places searchNearby found: $name');
            if (name != null && name.isNotEmpty && !_plusCodeRegex.hasMatch(name)) {
              completer.complete(name);
            } else {
              completer.complete(null);
            }
          } catch (e) {
            debugPrint('[$_tag] Error parsing Places result: $e');
            completer.complete(null);
          }
        }).toJS,
      );

      // Handle rejection
      final catchFn =
          (promise.getProperty('catch'.toJS) as JSFunction?) ?? (promise.getProperty('then'.toJS) as JSFunction);
      if (promise.hasProperty('catch'.toJS).toDart) {
        (promise.getProperty('catch'.toJS) as JSFunction).callAsFunction(
          promise,
          ((JSAny? error) {
            debugPrint('[$_tag] searchNearby rejected: $error');
            if (!completer.isCompleted) completer.complete(null);
          }).toJS,
        );
      }

      return completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[$_tag] searchNearby timed out');
          return null;
        },
      );
    } catch (e) {
      debugPrint('[$_tag] Places error: $e');
      return null;
    }
  }

  /// Geocoder-based reverse geocoding (fallback)
  static Future<String?> _geocoderReverse(double lat, double lng) async {
    try {
      final completer = Completer<String?>();

      // Call: new google.maps.Geocoder().geocode({location: {lat, lng}}, callback)
      final google = globalContext.getProperty('google'.toJS) as JSObject?;
      if (google == null || google.isUndefinedOrNull) return null;

      final maps = google.getProperty('maps'.toJS) as JSObject?;
      if (maps == null || maps.isUndefinedOrNull) return null;

      final geocoderClass = maps.getProperty('Geocoder'.toJS) as JSFunction?;
      if (geocoderClass == null) return null;

      // Create geocoder instance
      final geocoder = geocoderClass.callAsConstructor<JSObject>();

      // Build request: { location: { lat: lat, lng: lng } }
      final latLng = JSObject();
      latLng.setProperty('lat'.toJS, lat.toJS);
      latLng.setProperty('lng'.toJS, lng.toJS);

      final request = JSObject();
      request.setProperty('location'.toJS, latLng);
      request.setProperty('language'.toJS, 'ar'.toJS);

      // Define callback
      void callback(JSArray? results, JSAny? status) {
        try {
          final statusStr = (status as JSString?)?.toDart ?? '';
          debugPrint('[$_tag] Geocoder status: $statusStr, results: ${results?.toDart.length ?? 0}');
          if (statusStr != 'OK' || results == null) {
            completer.complete(null);
            return;
          }

          final resultsList = results.toDart;
          if (resultsList.isEmpty) {
            completer.complete(null);
            return;
          }

          // Look for POI/establishment type first
          for (int i = 0; i < resultsList.length; i++) {
            final resultObj = resultsList[i] as JSObject;
            final types = resultObj.getProperty('types'.toJS) as JSArray?;
            final formattedAddr = (resultObj.getProperty('formatted_address'.toJS) as JSString?)?.toDart ?? '';
            if (types != null) {
              final typesList = types.toDart.map((t) => (t as JSString).toDart).toList();
              debugPrint('[$_tag] Result[$i]: types=$typesList, addr=$formattedAddr');
              // Skip plus_code results
              if (typesList.contains('plus_code')) continue;
              if (typesList.any(
                (t) => [
                  'point_of_interest',
                  'establishment',
                  'museum',
                  'tourist_attraction',
                  'store',
                  'shopping_mall',
                  'restaurant',
                  'food',
                ].contains(t),
              )) {
                if (formattedAddr.isNotEmpty) {
                  // Extract a clean name: skip Plus Code parts
                  final name = _extractCleanName(formattedAddr);
                  if (name != null) {
                    debugPrint('[$_tag] ✓ Found POI: $name');
                    completer.complete(name);
                    return;
                  }
                }
              }
            }
          }

          // Fallback: find first route/street result with a clean name
          for (final result in resultsList) {
            final resultObj = result as JSObject;
            final types = resultObj.getProperty('types'.toJS) as JSArray?;
            final typesList = types?.toDart.map((t) => (t as JSString).toDart).toList() ?? [];
            // Skip plus_code and broad political/country types
            if (typesList.contains('plus_code')) continue;
            if (typesList.contains('country')) continue;
            if (typesList.contains('administrative_area_level_1')) continue;
            final formattedAddress = (resultObj.getProperty('formatted_address'.toJS) as JSString?)?.toDart;
            if (formattedAddress != null && formattedAddress.isNotEmpty) {
              final name = _extractCleanName(formattedAddress);
              if (name != null) {
                debugPrint('[$_tag] → Returning: $name');
                completer.complete(name);
                return;
              }
            }
          }

          // All results were Plus Codes or unusable
          debugPrint('[$_tag] No usable result found');
          completer.complete(null);
        } catch (e) {
          debugPrint('[$_tag] Error in geocoder callback: $e');
          completer.complete(null);
        }
      }

      // Call geocoder.geocode(request, callback)
      geocoder.callMethod('geocode'.toJS, request, callback.toJS);

      // Timeout after 8 seconds
      return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (e) {
      debugPrint('[$_tag] Error: $e');
      return null;
    }
  }

  /// Plus Code pattern: alphanumeric with a + sign, like "32PG+447" or "33WH+V72"
  static final _plusCodeRegex = RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]+$', caseSensitive: false);

  /// Extract a clean, human-readable name from a formatted_address string.
  /// Skips Plus Code parts and returns the first meaningful part.
  /// Example: "32PG+447, Rue Baker Ahmed, Nouakchott, موريتانيا" → "Rue Baker Ahmed"
  static String? _extractCleanName(String formattedAddress) {
    final parts = formattedAddress.split(',').map((p) => p.trim()).toList();

    for (final part in parts) {
      // Skip Plus Codes
      if (_plusCodeRegex.hasMatch(part)) continue;
      // Skip if it starts with a Plus Code (e.g., "32PG+447 Nouakchott")
      if (part.contains('+') && _plusCodeRegex.hasMatch(part.split(' ').first)) continue;
      // Skip very generic names (country, broad region)
      if (part == 'موريتانيا' || part == 'Mauritania') continue;
      // Found a good name
      if (part.isNotEmpty) return part;
    }
    return null;
  }
}
