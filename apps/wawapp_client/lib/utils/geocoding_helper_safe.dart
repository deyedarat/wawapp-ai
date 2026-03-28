import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingHelper {
  // API key from environment variables
  static const String _apiKey =
      String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  static Future<String> reverseGeocode(LatLng position) async {
    // FAIL-FAST: Check for missing API key
    if (_apiKey.isEmpty) {
      if (kDebugMode) {
        dev.log(
          '🚨 ERROR: Google Maps API key is missing!\n'
          'Returning fallback coordinates instead of address.\n'
          'See SECRETS_MANAGEMENT.md for setup instructions.',
          name: 'GeocodingHelperSafe',
          level: 1000, // WARNING
        );
      }

      // Return fallback with coordinates
      return 'نواكشوط، موريتانيا (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&key=$_apiKey'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] ?? 'موقع غير محدد';
        }
      }
      return 'فشل في جلب العنوان، تحقق من الاتصال بالإنترنت';
    } catch (e) {
      return 'فشل في جلب العنوان، تحقق من الاتصال بالإنترنت';
    }
  }
}
