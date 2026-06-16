import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/latlng.dart';
import '../utils/haversine.dart';

class QuoteState {
  final LatLng? pickup;
  final LatLng? dropoff;
  final double? distanceKm;
  final int? priceInMRU;

  const QuoteState({
    this.pickup,
    this.dropoff,
    this.distanceKm,
    this.priceInMRU,
  });

  QuoteState copyWith({
    LatLng? pickup,
    LatLng? dropoff,
    double? distanceKm,
    int? priceInMRU,
  }) {
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

  static const int baseFare = 50; // MRU
  static const int perKmRate = 20; // MRU
  static const int serviceFee = 10; // MRU

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
      final price = baseFare + (distance * perKmRate).round() + serviceFee;

      state = state.copyWith(
        distanceKm: distance,
        priceInMRU: price,
      );
    }
  }

  void reset() {
    state = const QuoteState();
  }
}

final quoteProvider = StateNotifierProvider<QuoteNotifier, QuoteState>((ref) {
  return QuoteNotifier();
});
