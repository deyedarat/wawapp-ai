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
          for (final result in resultsList) {
            final resultObj = result as JSObject;
            final types = resultObj.getProperty('types'.toJS) as JSArray?;
            if (types != null) {
              final typesList = types.toDart.map((t) => (t as JSString).toDart).toList();
              if (typesList.any(
                (t) => ['point_of_interest', 'establishment', 'premise', 'store', 'shopping_mall'].contains(t),
              )) {
                final formattedAddress = (resultObj.getProperty('formatted_address'.toJS) as JSString?)?.toDart;
                if (formattedAddress != null && formattedAddress.isNotEmpty) {
                  // Return just the POI name (first part before comma)
                  completer.complete(formattedAddress.split(',').first.trim());
                  return;
                }
              }
            }
          }

          // Fallback: first result, shortened
          final firstResult = resultsList[0] as JSObject;
          final formattedAddress = (firstResult.getProperty('formatted_address'.toJS) as JSString?)?.toDart;
          if (formattedAddress != null && formattedAddress.isNotEmpty) {
            final parts = formattedAddress.split(',');
            if (parts.length > 2) {
              completer.complete('${parts[0].trim()}, ${parts[1].trim()}');
            } else {
              completer.complete(formattedAddress);
            }
          } else {
            completer.complete(null);
          }
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
}
