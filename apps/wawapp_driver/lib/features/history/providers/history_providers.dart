import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/driver_history_repository.dart';

final driverHistoryRepositoryProvider =
    Provider<DriverHistoryRepository>((ref) {
  return DriverHistoryRepository();
});

final driverHistoryProvider =
    StreamProvider.autoDispose<List<Order>>((ref) {
  final repository = ref.watch(driverHistoryRepositoryProvider);
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value([]);
  }

  return repository.watchAllHistoryOrders(user.uid);
});
