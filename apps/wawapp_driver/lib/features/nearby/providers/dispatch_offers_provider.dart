import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/orders_service.dart';
import '../../orders/models/dispatch_offer.dart';

/// Provider that watches dispatch offers for the current driver (v2.0)
final dispatchOffersProvider =
    StreamProvider.autoDispose<List<DispatchOffer>>((ref) {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    // Return empty stream if no user is authenticated
    return Stream.value([]);
  }

  final ordersService = ref.watch(ordersServiceProvider);

  // Watch offers for current driver
  return ordersService.watchMyOffers(user.uid);
});

/// Provider for accepting an offer (v2.0)
final acceptOfferProvider =
    Provider.autoDispose<Future<void> Function(String, String)>((ref) {
  final ordersService = ref.watch(ordersServiceProvider);

  return (String offerId, String orderId) async {
    await ordersService.acceptOfferV2(
      offerId: offerId,
      orderId: orderId,
    );
  };
});

/// Provider for rejecting an offer (v2.0)
final rejectOfferProvider =
    Provider.autoDispose<Future<void> Function(String)>((ref) {
  final ordersService = ref.watch(ordersServiceProvider);

  return (String offerId) async {
    await ordersService.rejectOffer(offerId: offerId);
  };
});
