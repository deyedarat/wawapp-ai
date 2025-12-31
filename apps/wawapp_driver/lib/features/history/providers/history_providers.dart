import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../data/driver_history_repository.dart';
import '../../auth/providers/auth_service_provider.dart';
import '../../../core/config/testlab_flags.dart';
import '../../../core/config/testlab_mock_data.dart';

final driverHistoryRepositoryProvider =
    Provider<DriverHistoryRepository>((ref) {
  return DriverHistoryRepository();
});

final driverHistoryProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  // Return mock history for Test Lab mode
  if (TestLabFlags.safeEnabled) {
    return Stream.value(TestLabMockData.mockCompletedOrders);
  }

  final repository = ref.watch(driverHistoryRepositoryProvider);
  final authState = ref.watch(authProvider);

  if (authState.user == null) {
    return Stream.value([]);
  }

  return repository.watchAllHistoryOrders(authState.user!.uid);
});
