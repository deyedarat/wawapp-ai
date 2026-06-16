import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/latlng.dart';
import '../utils/haversine.dart';

class QuoteState {
  final LatLng? pickup;
  final LatLng? dropoff;
  final double? distanceKm;
  final int? priceInMRU;

  const QuoteState({this.pickup, this.dropoff, this.distanceKm, this.priceInMRU});

  QuoteState copyWith({LatLng? pickup, LatLng? dropoff, double? distanceKm, int? priceInMRU}) {
    return QuoteState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      distanceKm: distanceKm ?? this.distanceKm,
      priceInMRU: priceInMRU ?? this.priceInMRU,
    );
  }

  bool get isReady => pickup != null && dropoff != null && priceInMRU != null;
}

class QuoteNotifier extends StateNotifier<QuoteState> {
  QuoteNotifier() : super(const QuoteState());

  void setPickup(LatLng pickup) {
    state = state.copyWith(pickup: pickup);
    _calculatePrice();
  }

  void setDropoff(LatLng dropoff) {
    state = state.copyWith(dropoff: dropoff);
    _calculatePrice();
  }

  void setDistance(double distance) {
    state = state.copyWith(distanceKm: distance);
  }

  void setPrice(int price) {
    state = state.copyWith(priceInMRU: price);
  }

  void _calculatePrice() {
    if (state.pickup != null && state.dropoff != null) {
      final distance = distanceKm(state.pickup!, state.dropoff!);
      // Use canonical pricing from core_shared (base=60, perKm=20, minFare=100)
      final base = 60;
      final price = base + (distance * 20).round();
      final withMin = price < 100 ? 100 : price;
      // Round to nearest 5
      final rounded = ((withMin / 5).round() * 5);

      state = state.copyWith(distanceKm: distance, priceInMRU: rounded);
    }
  }

  void reset() {
    state = const QuoteState();
  }
}

final quoteProvider = StateNotifierProvider<QuoteNotifier, QuoteState>((ref) {
  return QuoteNotifier();
});
