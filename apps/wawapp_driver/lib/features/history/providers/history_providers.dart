import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/order.dart' as app_order;
import '../data/driver_history_repository.dart';

final driverHistoryRepositoryProvider = Provider<DriverHistoryRepository>((ref) {
  return DriverHistoryRepository();
});

final driverHistoryProvider = StreamProvider.autoDispose<List<app_order.Order>>((ref) {
  final repository = ref.watch(driverHistoryRepositoryProvider);
  final user = FirebaseAuth.instance.currentUser;
  
  if (user == null) {
    return Stream.value([]);
  }
  
  return repository.watchCompletedOrders(user.uid);
});