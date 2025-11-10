import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GeocodingHelper {
  GeocodingHelper(this.apiKey) {
    if (apiKey.isEmpty) {
      dev.log('⚠️ MAPS_API_KEY is empty. Geocoding may not work.',
          name: 'GeocodingHelper');
    }
  }

  final String apiKey;

  Future<String> reverseGeocode(LatLng position) async {
    if (apiKey.isEmpty) {
      dev.log('Cannot reverse geocode: API key is empty',
          name: 'GeocodingHelper');
      return 'مفتاح API غير متوفر';
    }

    try {
      final url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=${position.latitude},${position.longitude}'
          '&key=$apiKey'
          '&language=ar';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'] ?? 'موقع غير محدد';
        }
      } else {
        dev.log('Geocoding API returned status ${response.statusCode}',
            name: 'GeocodingHelper');
      }
      return 'فشل في جلب العنوان، تحقق من الاتصال بالإنترنت';
    } catch (e) {
      dev.log('Error in reverseGeocode: $e', name: 'GeocodingHelper');
      return 'فشل في جلب العنوان، تحقق من الاتصال بالإنترنت';
    }
  }
}

final geocodingHelperProvider = Provider<GeocodingHelper>((ref) {
  const key = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  return GeocodingHelper(key);
});
