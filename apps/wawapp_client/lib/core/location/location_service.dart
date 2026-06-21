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
    // Try Google Geocoding API first (returns better results for Arabic)
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$lat,$lng&key=$apiKey&language=ar',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            // Prefer a result with a short name (POI, neighborhood, etc.)
            final address = _extractBestAddress(results);
            if (address != null) {
              dev.log('Google Geocoding resolved: $address', name: _tag);
              return address;
            }
          }
        }
      } catch (e) {
        dev.log('Google Geocoding error, falling back to Nominatim: $e', name: _tag);
      }
    }

    // Fallback: Nominatim (free, no API key needed)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp/1.0'}).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          dev.log('Nominatim resolved: $displayName', name: _tag);
          return displayName;
        }
      }

      dev.log('Nominatim returned no result, using coordinates', name: _tag);
      return '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
    } catch (e) {
      dev.log('Reverse geocoding error: $e', name: _tag);
      return '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
    }
  }

  /// Extract the best short address from Google Geocoding results.
  /// Prefers: POI name > neighborhood > route > formatted_address.
  static String? _extractBestAddress(List<dynamic> results) {
    // Look for point_of_interest, establishment, or premise type first
    for (final result in results) {
      final types = (result['types'] as List<dynamic>?)?.cast<String>() ?? [];
      if (types.any((t) => ['point_of_interest', 'establishment', 'premise'].contains(t))) {
        final name = result['formatted_address'] as String?;
        if (name != null && name.isNotEmpty) {
          // Return just the first part (before the first comma) for a shorter name
          return name.split(',').first.trim();
        }
      }
    }

    // Fallback: use the first result's short form
    if (results.isNotEmpty) {
      final firstResult = results[0];
      final address = firstResult['formatted_address'] as String?;
      if (address != null && address.isNotEmpty) {
        // Take the first two parts for a reasonable length
        final parts = address.split(',');
        if (parts.length > 2) {
          return '${parts[0].trim()}, ${parts[1].trim()}';
        }
        return address;
      }
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
