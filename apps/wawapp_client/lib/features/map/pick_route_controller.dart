import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../core/location/location_service.dart';

// Use Google Maps LatLng directly to avoid conflicts
typedef MapLatLng = LatLng;

class RoutePickerState {
  final MapLatLng? pickup;
  final MapLatLng? dropoff;
  final String pickupAddress;
  final String dropoffAddress;
  final bool selectingPickup;
  final double? distanceKm;

  const RoutePickerState({
    this.pickup,
    this.dropoff,
    this.pickupAddress = '',
    this.dropoffAddress = '',
    this.selectingPickup = true,
    this.distanceKm,
  });

  RoutePickerState copyWith({
    MapLatLng? pickup,
    MapLatLng? dropoff,
    String? pickupAddress,
    String? dropoffAddress,
    bool? selectingPickup,
    double? distanceKm,
  }) {
    return RoutePickerState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      selectingPickup: selectingPickup ?? this.selectingPickup,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  bool get canCalculatePrice => pickup != null && dropoff != null;
}

class RoutePickerNotifier extends StateNotifier<RoutePickerState> {
  RoutePickerNotifier() : super(const RoutePickerState());

  static const String _mapsApiKey = String.fromEnvironment('MAPS_API_KEY',
      defaultValue: '');
  late final GooglePlace _googlePlace = GooglePlace(_mapsApiKey);
  final Uuid _uuid = const Uuid();

  void toggleSelection() {
    state = state.copyWith(selectingPickup: !state.selectingPickup);
  }

  Future<void> setLocationFromTap(MapLatLng location) async {
    // Set loading state
    if (state.selectingPickup) {
      state = state.copyWith(
          pickup: location, pickupAddress: 'جارٍ تحديد العنوان...');
    } else {
      state = state.copyWith(
          dropoff: location, dropoffAddress: 'جارٍ تحديد العنوان...');
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

    try {
      final result = await _googlePlace.autocomplete.get(
        query,
        sessionToken: _uuid.v4(),
        language: 'ar',
        components: [Component('country', 'mr')], // Mauritania
      );

      return result?.predictions ?? [];
    } catch (e) {
      return [];
    }
  }

  Future<DetailsResult?> getPlaceDetails(String placeId) async {
    try {
      final result = await _googlePlace.details.get(
        placeId,
        sessionToken: _uuid.v4(),
        language: 'ar',
      );
      return result?.result;
    } catch (e) {
      return null;
    }
  }

  void _calculateDistance() {
    if (state.pickup != null && state.dropoff != null) {
      final distance = Geolocator.distanceBetween(
            state.pickup!.latitude,
            state.pickup!.longitude,
            state.dropoff!.latitude,
            state.dropoff!.longitude,
          ) /
          1000; // Convert to km

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
  return RoutePickerNotifier();
});
