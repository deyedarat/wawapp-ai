import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/models/request.dart';
import '../../../services/location_service.dart';

class NearbyRepository {
  final FirebaseFirestore _firestore;

  NearbyRepository(this._firestore);

  Stream<List<Request>> getNearbyRequests(Position position) {
    return _firestore
        .collection('orders')
        .where('status', isEqualTo: 'matching')
        .snapshots()
        .map((snapshot) {
      final requests = <Request>[];
      for (final doc in snapshot.docs) {
        try {
          final request = Request.fromFirestore(doc.id, doc.data());
          final distance = _calculateDistance(
            position.latitude,
            position.longitude,
            request.pickup.lat,
            request.pickup.lng,
          );
          if (distance <= 8.0) requests.add(request);
        } catch (_) {}
      }
      requests.sort((a, b) {
        final distA = _calculateDistance(
            position.latitude, position.longitude, a.pickup.lat, a.pickup.lng);
        final distB = _calculateDistance(
            position.latitude, position.longitude, b.pickup.lat, b.pickup.lng);
        return distA.compareTo(distB);
      });
      return requests;
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

final nearbyRepositoryProvider = Provider<NearbyRepository>((ref) {
  return NearbyRepository(FirebaseFirestore.instance);
});

final nearbyRequestsProvider = StreamProvider<List<Request>>((ref) async* {
  final position = await LocationService.instance.getCurrentPosition();
  final repository = ref.watch(nearbyRepositoryProvider);
  yield* repository.getNearbyRequests(position);
});
