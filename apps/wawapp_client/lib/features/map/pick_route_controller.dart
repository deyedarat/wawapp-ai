import 'dart:developer' as dev;

import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:uuid/uuid.dart';

import '../../core/geo/distance.dart';
import '../../core/location/location_service.dart';
import 'providers/shared_places_provider.dart';

// Use Google Maps LatLng directly to avoid conflicts
typedef MapLatLng = LatLng;

/// Provider for Google Maps API key
/// CRITICAL: Must be set via --dart-define=GOOGLE_MAPS_API_KEY=your_key
/// or in api_keys.xml for Android builds
final mapsApiKeyProvider = Provider<String>((ref) {
  const key = String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');

  // FAIL-FAST: Validate API key in debug mode
  if (kDebugMode && key.isEmpty) {
    dev.log(
      '🚨 CRITICAL: GOOGLE_MAPS_API_KEY is not set!\n'
      'Maps and geocoding features will NOT work.\n'
      '\n'
      'Setup options:\n'
      '1. Build with: flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key\n'
      '2. Create api_keys.xml (see SECRETS_MANAGEMENT.md)\n'
      '3. Copy .env.example to .env and set GOOGLE_MAPS_API_KEY\n',
      name: 'MapApi Key',
      level: 2000, // SEVERE
    );
  }

  return key;
});

class RoutePickerState {
  final MapLatLng? pickup;
  final MapLatLng? dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final bool selectingPickup;
  final double? distanceKm;
  final bool mapsEnabled;

  const RoutePickerState({
    this.pickup,
    this.dropoff,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.selectingPickup = true,
    this.distanceKm,
    this.mapsEnabled = true,
  });

  RoutePickerState copyWith({
    MapLatLng? pickup,
    MapLatLng? dropoff,
    String? pickupAddress,
    String? dropoffAddress,
    bool? selectingPickup,
    double? distanceKm,
    bool? mapsEnabled,
  }) {
    return RoutePickerState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      selectingPickup: selectingPickup ?? this.selectingPickup,
      distanceKm: distanceKm ?? this.distanceKm,
      mapsEnabled: mapsEnabled ?? this.mapsEnabled,
    );
  }

  bool get canCalculatePrice => pickup != null && dropoff != null;
}

class RoutePickerNotifier extends StateNotifier<RoutePickerState> {
  RoutePickerNotifier(this.apiKey, this._sharedPlaces) : super(const RoutePickerState(mapsEnabled: true));

  final String apiKey;
  final List<SharedPlace> _sharedPlaces;
  static const String _tag = 'RoutePickerNotifier';

  /// Max distance (in km) to match a tap to a shared place
  static const double _sharedPlaceMatchRadiusKm = 0.1; // 100 meters

  late final GooglePlace? _googlePlace = apiKey.isNotEmpty ? GooglePlace(apiKey) : null;
  final Uuid _uuid = const Uuid();

  /// Find the nearest shared place within match radius.
  /// Returns null if no shared place is close enough.
  SharedPlace? _findNearbySharedPlace(double lat, double lng) {
    SharedPlace? closest;
    double closestDistance = double.infinity;

    for (final place in _sharedPlaces) {
      final distance = computeDistanceKm(lat1: lat, lng1: lng, lat2: place.latitude, lng2: place.longitude);
      if (distance < _sharedPlaceMatchRadiusKm && distance < closestDistance) {
        closest = place;
        closestDistance = distance;
      }
    }

    if (closest != null) {
      dev.log('Matched shared place: ${closest.name} (${closestDistance * 1000}m away)', name: _tag);
    }

    return closest;
  }

  void toggleSelection() {
    state = state.copyWith(selectingPickup: !state.selectingPickup);
  }

  Future<void> setLocationFromTap(MapLatLng location) async {
    // Set loading state
    if (state.selectingPickup) {
      state = state.copyWith(pickup: location, pickupAddress: 'جار تحديد العنوان...');
    } else {
      state = state.copyWith(dropoff: location, dropoffAddress: 'جار تحديد العنوان...');
    }

    // 1) Check if tap is near a known shared place (free, no API call)
    final nearbyPlace = _findNearbySharedPlace(location.latitude, location.longitude);
    final String address;

    if (nearbyPlace != null) {
      address = nearbyPlace.name;
    } else {
      // 2) Fallback to reverse geocoding (Google first, then Nominatim)
      address = await LocationService.resolveAddressFromLatLng(location.latitude, location.longitude, apiKey: apiKey);
    }

    if (state.selectingPickup) {
      state = state.copyWith(pickupAddress: address);
    } else {
      state = state.copyWith(dropoffAddress: address);
    }

    _calculateDistance();
  }

  Future<void> setLocationFromPlace(DetailsResult place, bool isPickup) async {
    final lat = place.geometry?.location?.lat;
    final lng = place.geometry?.location?.lng;

    if (lat != null && lng != null) {
      final location = MapLatLng(lat, lng);
      final address = place.formattedAddress ?? place.name ?? 'موقع غير محدد';

      if (isPickup) {
        state = state.copyWith(pickup: location, pickupAddress: address);
      } else {
        state = state.copyWith(dropoff: location, dropoffAddress: address);
      }

      _calculateDistance();
    }
  }

  Future<List<AutocompletePrediction>> searchPlaces(String query) async {
    if (query.isEmpty) return [];
    if (!state.mapsEnabled || _googlePlace == null) {
      dev.log('Cannot search places: Maps disabled (no API key)', name: _tag);
      return [];
    }

    try {
      final result = await _googlePlace!.autocomplete.get(
        query,
        sessionToken: _uuid.v4(),
        language: 'ar',
        components: [Component('country', 'mr')], // Mauritania
      );

      return result?.predictions ?? [];
    } catch (e) {
      dev.log('Error searching places: $e', name: _tag);
      return [];
    }
  }

  Future<DetailsResult?> getPlaceDetails(String placeId) async {
    if (!state.mapsEnabled || _googlePlace == null) {
      dev.log('Cannot get place details: Maps disabled (no API key)', name: _tag);
      return null;
    }

    try {
      final result = await _googlePlace!.details.get(placeId, sessionToken: _uuid.v4(), language: 'ar');
      return result?.result;
    } catch (e) {
      dev.log('Error getting place details: $e', name: _tag);
      return null;
    }
  }

  void _calculateDistance() {
    if (state.pickup != null && state.dropoff != null) {
      final distance = computeDistanceKm(
        lat1: state.pickup!.latitude,
        lng1: state.pickup!.longitude,
        lat2: state.dropoff!.latitude,
        lng2: state.dropoff!.longitude,
      );

      state = state.copyWith(distanceKm: distance);
    }
  }

  Future<void> setCurrentLocation() async {
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final location = MapLatLng(position.latitude, position.longitude);
      await setLocationFromTap(location);
    }
  }

  Future<void> setAddressFromText(String address, bool isPickup) async {
    final location = await LocationService.resolveLatLngFromAddress(address);
    if (location != null) {
      if (isPickup) {
        state = state.copyWith(pickup: location, pickupAddress: address);
      } else {
        state = state.copyWith(dropoff: location, dropoffAddress: address);
      }
      _calculateDistance();
    }
  }

  Future<void> setLocationFromSavedLocation(SavedLocation savedLocation, bool isPickup) async {
    final location = MapLatLng(savedLocation.latitude, savedLocation.longitude);
    final address = savedLocation.address;

    if (isPickup) {
      state = state.copyWith(pickup: location, pickupAddress: address);
    } else {
      state = state.copyWith(dropoff: location, dropoffAddress: address);
    }

    _calculateDistance();
  }

  void setLocationExplicitly(MapLatLng location, String address, bool isPickup) {
    if (isPickup) {
      state = state.copyWith(pickup: location, pickupAddress: address);
    } else {
      state = state.copyWith(dropoff: location, dropoffAddress: address);
    }
    _calculateDistance();
  }

  void reset() {
    state = const RoutePickerState();
  }
}

final routePickerProvider = StateNotifierProvider<RoutePickerNotifier, RoutePickerState>((ref) {
  final apiKey = ref.watch(mapsApiKeyProvider);
  final sharedPlaces = ref.watch(sharedPlacesProvider).valueOrNull ?? [];
  return RoutePickerNotifier(apiKey, sharedPlaces);
});
