/**
 * Admin Data Providers
 * Riverpod providers for admin panel data (orders, drivers, clients)
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../services/admin_orders_service.dart';
import '../services/admin_drivers_service.dart';
import '../services/admin_clients_service.dart';

// ============================================================================
// Service Providers
// ============================================================================

final adminOrdersServiceProvider = Provider<AdminOrdersService>((ref) {
  return AdminOrdersService();
});

final adminDriversServiceProvider = Provider<AdminDriversService>((ref) {
  return AdminDriversService();
});

final adminClientsServiceProvider = Provider<AdminClientsService>((ref) {
  return AdminClientsService();
});

// ============================================================================
// Orders Providers
// ============================================================================

/// Orders stream with optional status filter
final ordersStreamProvider = StreamProvider.family<List<Order>, String?>((ref, statusFilter) {
  final service = ref.watch(adminOrdersServiceProvider);
  return service.getOrdersStream(statusFilter: statusFilter);
});

/// All orders (no filter)
final allOrdersProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(ordersStreamProvider(null).stream);
});

/// Order statistics
final orderStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(adminOrdersServiceProvider);
  return await service.getOrderStats();
});

// ============================================================================
// Drivers Providers
// ============================================================================

/// Drivers stream with optional online filter
final driversStreamProvider = StreamProvider.family<List<DriverProfile>, bool?>((ref, onlineOnly) {
  final service = ref.watch(adminDriversServiceProvider);
  return service.getDriversStream(onlineOnly: onlineOnly);
});

/// All drivers (no filter)
final allDriversProvider = StreamProvider<List<DriverProfile>>((ref) {
  return ref.watch(driversStreamProvider(null).stream);
});

/// Driver statistics
final driverStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(adminDriversServiceProvider);
  return await service.getDriverStats();
});

// ============================================================================
// Clients Providers
// ============================================================================

/// Clients stream with optional verified filter
final clientsStreamProvider = StreamProvider.family<List<ClientProfile>, bool?>((ref, verifiedOnly) {
  final service = ref.watch(adminClientsServiceProvider);
  return service.getClientsStream(verifiedOnly: verifiedOnly);
});

/// All clients (no filter)
final allClientsProvider = StreamProvider<List<ClientProfile>>((ref) {
  return ref.watch(clientsStreamProvider(null).stream);
});

/// Client statistics
final clientStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(adminClientsServiceProvider);
  return await service.getClientStats();
});

// ============================================================================
// Dashboard Stats Provider (combines all stats)
// ============================================================================

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final orderStats = await ref.watch(orderStatsProvider.future);
  final driverStats = await ref.watch(driverStatsProvider.future);
  final clientStats = await ref.watch(clientStatsProvider.future);

  return {
    'orders': orderStats,
    'drivers': driverStats,
    'clients': clientStats,
  };
});
