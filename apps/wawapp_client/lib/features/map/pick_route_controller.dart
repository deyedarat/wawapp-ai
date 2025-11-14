import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:uuid/uuid.dart';
import '../../core/geo/distance.dart';
import '../../core/location/location_service.dart';

// Use Google Maps LatLng directly to avoid conflicts
typedef MapLatLng = LatLng;

final mapsApiKeyProvider = Provider<String>((ref) {
  const key = String.fromEnvironment('MAPS_API_KEY', defaultValue: '');
  if (key.isEmpty) {
    dev.log('⚠️ MAPS_API_KEY is empty. Map features may not work.',
        name: 'MAP');
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
  RoutePickerNotifier(this.apiKey)
      : super(RoutePickerState(mapsEnabled: apiKey.isNotEmpty)) {
    if (apiKey.isEmpty) {
      dev.log(
          '[MapConfig] MAPS_API_KEY is empty – map features disabled in this build.',
          name: _tag);
    }
  }

  final String apiKey;
  static const String _tag = 'RoutePickerNotifier';

  late final GooglePlace? _googlePlace =
      apiKey.isNotEmpty ? GooglePlace(apiKey) : null;
  final Uuid _uuid = const Uuid();

  void toggleSelection() {
    state = state.copyWith(selectingPickup: !state.selectingPickup);
  }

  Future<void> setLocationFromTap(MapLatLng location) async {
    // Set loading state
    if (state.selectingPickup) {
      state = state.copyWith(
          pickup: location, pickupAddress: 'جار تحديد العنوان...');
    } else {
      state = state.copyWith(
          dropoff: location, dropoffAddress: 'جار تحديد العنوان...');
    }

    final address = await LocationService.resolveAddressFromLatLng(
        location.latitude, location.longitude);

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
      dev.log('Cannot get place details: Maps disabled (no API key)',
          name: _tag);
      return null;
    }

    try {
      final result = await _googlePlace!.details.get(
        placeId,
        sessionToken: _uuid.v4(),
        language: 'ar',
      );
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

  void reset() {
    state = const RoutePickerState();
  }
}

final routePickerProvider =
    StateNotifierProvider<RoutePickerNotifier, RoutePickerState>((ref) {
  return RoutePickerNotifier(ref.watch(mapsApiKeyProvider));
});
