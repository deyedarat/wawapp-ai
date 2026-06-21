import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class LocationService {
  static const String _tag = 'WAWAPP_LOC';

  static Future<bool> checkPermissions() async {
    dev.log('Checking location permissions...', name: _tag);
    LocationPermission permission = await Geolocator.checkPermission();
    dev.log('Current permission: $permission', name: _tag);

    if (permission == LocationPermission.denied) {
      dev.log('Requesting location permission...', name: _tag);
      permission = await Geolocator.requestPermission();
      dev.log('Permission after request: $permission', name: _tag);
    }

    final hasPermission = permission == LocationPermission.whileInUse || permission == LocationPermission.always;
    dev.log('Has location permission: $hasPermission', name: _tag);
    return hasPermission;
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      dev.log('Getting current position...', name: _tag);
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        dev.log('Location permission denied', name: _tag);
        return null;
      }

      final isEnabled = await Geolocator.isLocationServiceEnabled();
      dev.log('Location services enabled: $isEnabled', name: _tag);
      if (!isEnabled) {
        dev.log('Location services disabled', name: _tag);
        return null;
      }

      dev.log('Requesting GPS position...', name: _tag);
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      dev.log('Got position: ${position.latitude}, ${position.longitude}', name: _tag);
      return position;
    } catch (e) {
      dev.log('Error getting current position: $e', name: _tag);
      return null;
    }
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    );
  }

  /// Reverse geocoding via Google Geocoding API (with Nominatim fallback).
  /// Tries Google first if apiKey is provided, falls back to Nominatim.
  /// Returns coordinates string as fallback if all requests fail.
  static Future<String> resolveAddressFromLatLng(double lat, double lng, {String? apiKey}) async {
    // 1) Try Places API Nearby Search for POI name (best results)
    if (apiKey != null && apiKey.isNotEmpty) {
      final poiName = await _findNearbyPlaceName(lat, lng, apiKey);
      if (poiName != null) {
        dev.log('Places API resolved: $poiName', name: _tag);
        return poiName;
      }
    }

    // 2) Fallback: Nominatim (free)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp/1.0'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final name = data['name'] as String?;
        // If Nominatim has a POI name, use it
        if (name != null && name.isNotEmpty) {
          dev.log('Nominatim POI name: $name', name: _tag);
          return name;
        }
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          // Shorten to first meaningful part
          final parts = displayName.split(',');
          final short = parts.length > 2 ? '${parts[0].trim()}, ${parts[1].trim()}' : displayName;
          dev.log('Nominatim resolved: $short', name: _tag);
          return short;
        }
      }

      dev.log('Nominatim returned no result, using coordinates', name: _tag);
      return '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
    } catch (e) {
      dev.log('Reverse geocoding error: $e', name: _tag);
      return '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
    }
  }

  /// Plus Code pattern
  static final _plusCodeRegex = RegExp(r'^[A-Z0-9]{4,}\+[A-Z0-9]+', caseSensitive: false);

  /// Use Places API (New) Nearby Search to find the nearest POI name.
  /// This returns the actual place name (e.g., "كرفور BMD") not just the address.
  static Future<String?> _findNearbyPlaceName(double lat, double lng, String apiKey) async {
    try {
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
      final body = json.encode({
        'maxResultCount': 1,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 50.0,
          },
        },
      });

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'places.displayName',
              'Accept-Language': 'ar',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final places = data['places'] as List<dynamic>?;
        if (places != null && places.isNotEmpty) {
          final displayName = places[0]['displayName'] as Map<String, dynamic>?;
          final name = displayName?['text'] as String?;
          if (name != null && name.isNotEmpty && !_plusCodeRegex.hasMatch(name)) {
            return name;
          }
        }
      } else {
        dev.log('Places API error ${response.statusCode}: ${response.body}', name: _tag);
      }
    } catch (e) {
      dev.log('Places API error: $e', name: _tag);
    }
    return null;
  }

  static Future<LatLng?> resolveLatLngFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address).timeout(const Duration(seconds: 5));

      if (locations.isNotEmpty) {
        final location = locations.first;
        return LatLng(location.latitude, location.longitude);
      }

      return null;
    } catch (e) {
      dev.log('Forward geocoding error: $e', name: _tag);
      return null;
    }
  }
}
