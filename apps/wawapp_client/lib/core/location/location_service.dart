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

    final hasPermission = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
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
      dev.log('Got position: ${position.latitude}, ${position.longitude}',
          name: _tag);
      return position;
    } catch (e) {
      dev.log('Error getting current position: $e', name: _tag);
      return null;
    }
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Reverse geocoding via Nominatim (OpenStreetMap) — no API key required.
  /// Returns coordinates string as fallback if the request fails.
  static Future<String> resolveAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'WawApp/1.0'},
      ).timeout(const Duration(seconds: 8));

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

  static Future<LatLng?> resolveLatLngFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address)
          .timeout(const Duration(seconds: 5));

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
