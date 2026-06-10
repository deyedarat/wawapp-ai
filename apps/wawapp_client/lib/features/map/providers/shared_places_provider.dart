import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that streams all active shared places from Firestore.
/// These are admin-managed places visible to all users.
final sharedPlacesProvider = StreamProvider<List<SharedPlace>>((ref) {
  return FirebaseFirestore.instance.collection('shared_places').where('isActive', isEqualTo: true).snapshots().map((
    snapshot,
  ) {
    return snapshot.docs.map((doc) => SharedPlace.fromFirestore(doc)).toList();
  });
});

/// Filtered shared places based on search query
final filteredSharedPlacesProvider = Provider.family<List<SharedPlace>, String>((ref, query) {
  final placesAsync = ref.watch(sharedPlacesProvider);
  return placesAsync.maybeWhen(
    data: (places) {
      if (query.isEmpty) return places;
      final lowerQuery = query.toLowerCase();
      return places.where((place) {
        return place.name.toLowerCase().contains(lowerQuery) ||
            place.address.toLowerCase().contains(lowerQuery) ||
            (place.category?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    },
    orElse: () => [],
  );
});
