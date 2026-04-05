import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_service_provider.dart';

/// Lightweight data class for accepted-order timeout fields.
class AcceptedOrderMeta {
  const AcceptedOrderMeta({
    required this.orderId,
    required this.acceptedAtMs,
    required this.extensionRequestCount,
  });

  final String orderId;
  final int acceptedAtMs;
  final int extensionRequestCount;

  static const baseTimeoutMinutes = 5;
  static const extensionMinutes = 2;

  int get totalTimeoutMs =>
      (baseTimeoutMinutes + extensionRequestCount * extensionMinutes) * 60000;
}

/// Streams the first accepted order's timeout metadata for the current driver.
/// Returns null when no accepted order exists.
final acceptedOrderMetaProvider =
    StreamProvider.autoDispose<AcceptedOrderMeta?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('orders')
      .where('assignedDriverId', isEqualTo: user.uid)
      .where('status', isEqualTo: 'accepted')
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    final data = doc.data();
    final acceptedAt = data['acceptedAt'];
    int acceptedAtMs = 0;
    if (acceptedAt is Timestamp) {
      acceptedAtMs = acceptedAt.millisecondsSinceEpoch;
    }
    if (acceptedAtMs == 0) return null;

    return AcceptedOrderMeta(
      orderId: doc.id,
      acceptedAtMs: acceptedAtMs,
      extensionRequestCount: (data['extensionRequestCount'] as int?) ?? 0,
    );
  });
});
