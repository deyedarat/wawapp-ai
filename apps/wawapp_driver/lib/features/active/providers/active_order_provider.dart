import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../../../services/orders_service.dart';
import '../../auth/providers/auth_service_provider.dart';

final activeOrdersProvider = StreamProvider.autoDispose<List<Order>>((ref) {
  final authState = ref.watch(authProvider);
  if (authState.user == null) {
    return Stream.value([]);
  }

  final ordersService = OrdersService();
  return ordersService.getDriverActiveOrders(authState.user!.uid);
});
