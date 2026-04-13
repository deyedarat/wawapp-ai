import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reports/models/report_models.dart';
import '../features/reports/models/reports_filter_state.dart';

/// Reports filter state provider
final reportsFilterProvider = StateProvider<ReportsFilterState>((ref) {
  return ReportsFilterState.last7Days();
});

// ─── Firestore Fallback Helpers ──────────────────────────────────────────────

/// Builds overview data directly from Firestore when Functions aren't deployed.
Future<OverviewReportData> _fetchOverviewFromFirestore(
    ReportsFilterState filter) async {
  final fs = FirebaseFirestore.instance;
  final startTs = Timestamp.fromDate(filter.startDate);
  final endTs = Timestamp.fromDate(filter.endDate);

  // Orders in period
  final ordersSnap = await fs
      .collection('orders')
      .where('createdAt', isGreaterThanOrEqualTo: startTs)
      .where('createdAt', isLessThanOrEqualTo: endTs)
      .get();

  final orders = ordersSnap.docs;
  final total = orders.length;
  final completed = orders.where((d) => d['status'] == 'completed').length;
  final cancelled = orders.where((d) => d['status'] == 'cancelled').length;

  final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;

  // Average order value (field 'price' or 'totalPrice')
  int sumPrice = 0;
  for (final d in orders) {
    final data = d.data();
    sumPrice += ((data['price'] ?? data['totalPrice'] ?? 0) as num).toInt();
  }
  final avgValue = total > 0 ? (sumPrice / total).round() : 0;

  // Active drivers (isOnline = true)
  final driversSnap =
      await fs.collection('drivers').where('isOnline', isEqualTo: true).get();

  // New clients in period
  final clientsSnap = await fs
      .collection('clients')
      .where('createdAt', isGreaterThanOrEqualTo: startTs)
      .where('createdAt', isLessThanOrEqualTo: endTs)
      .get();

  return OverviewReportData(
    totalOrders: total,
    completedOrders: completed,
    cancelledOrders: cancelled,
    completionRate: completionRate,
    averageOrderValue: avgValue,
    totalActiveDrivers: driversSnap.size,
    newClients: clientsSnap.size,
    periodStart: filter.startDate.toIso8601String(),
    periodEnd: filter.endDate.toIso8601String(),
  );
}

/// Builds financial data directly from Firestore when Functions aren't deployed.
Future<FinancialReportData> _fetchFinancialFromFirestore(
    ReportsFilterState filter) async {
  final fs = FirebaseFirestore.instance;
  final startTs = Timestamp.fromDate(filter.startDate);
  final endTs = Timestamp.fromDate(filter.endDate);

  final ordersSnap = await fs
      .collection('orders')
      .where('status', isEqualTo: 'completed')
      .where('completedAt', isGreaterThanOrEqualTo: startTs)
      .where('completedAt', isLessThanOrEqualTo: endTs)
      .get();

  int grossRevenue = 0;
  int driverEarnings = 0;

  for (final doc in ordersSnap.docs) {
    final data = doc.data();
    grossRevenue += ((data['price'] ?? data['totalPrice'] ?? 0) as num).toInt();
    driverEarnings += ((data['driverEarning'] ?? 0) as num).toInt();
  }

  final platformCommission = grossRevenue - driverEarnings;

  return FinancialReportData(
    summary: FinancialSummary(
      totalOrders: ordersSnap.size,
      grossRevenue: grossRevenue,
      totalDriverEarnings: driverEarnings,
      totalPlatformCommission: platformCommission > 0 ? platformCommission : 0,
      averageCommissionRate: grossRevenue > 0
          ? ((platformCommission / grossRevenue) * 100).round()
          : 0,
    ),
    dailyBreakdown: [],
    periodStart: filter.startDate.toIso8601String(),
    periodEnd: filter.endDate.toIso8601String(),
  );
}

/// Builds driver performance data directly from Firestore.
Future<DriverPerformanceReportData> _fetchDriverPerfFromFirestore(
    ReportsFilterState filter) async {
  final fs = FirebaseFirestore.instance;
  final startTs = Timestamp.fromDate(filter.startDate);
  final endTs = Timestamp.fromDate(filter.endDate);

  final ordersSnap = await fs
      .collection('orders')
      .where('status', isEqualTo: 'completed')
      .where('completedAt', isGreaterThanOrEqualTo: startTs)
      .where('completedAt', isLessThanOrEqualTo: endTs)
      .get();

  // Aggregate by driverId
  final Map<String, Map<String, dynamic>> byDriver = {};
  for (final doc in ordersSnap.docs) {
    final data = doc.data();
    final driverId = data['driverId'] as String? ?? '';
    if (driverId.isEmpty) continue;
    byDriver.putIfAbsent(
        driverId,
        () => {
              'driverId': driverId,
              'driverName': data['driverName'] ?? 'سائق',
              'completedOrders': 0,
              'totalEarnings': 0,
              'totalRating': 0.0,
              'ratingCount': 0,
            });
    byDriver[driverId]!['completedOrders'] =
        (byDriver[driverId]!['completedOrders'] as int) + 1;
    byDriver[driverId]!['totalEarnings'] =
        (byDriver[driverId]!['totalEarnings'] as int) +
            ((data['driverEarning'] ?? 0) as num).toInt();
    final rating = (data['rating'] ?? 0) as num;
    if (rating > 0) {
      byDriver[driverId]!['totalRating'] =
          (byDriver[driverId]!['totalRating'] as double) + rating.toDouble();
      byDriver[driverId]!['ratingCount'] =
          (byDriver[driverId]!['ratingCount'] as int) + 1;
    }
  }

  final drivers = byDriver.values.map((d) {
    final rc = d['ratingCount'] as int;
    final avgRating =
        rc > 0 ? ((d['totalRating'] as double) / rc * 10).round() / 10 : 5.0;
    return DriverPerformance(
      driverId: d['driverId'] as String,
      name: d['driverName'] as String,
      phone: '',
      operator: '',
      totalTrips: d['completedOrders'] as int,
      completedTrips: d['completedOrders'] as int,
      cancelledTrips: 0,
      totalEarnings: d['totalEarnings'] as int,
      averageRating: avgRating,
      cancellationRate: 0,
    );
  }).toList()
    ..sort((a, b) => b.completedTrips.compareTo(a.completedTrips));

  return DriverPerformanceReportData(
    drivers: drivers,
    periodStart: filter.startDate.toIso8601String(),
    periodEnd: filter.endDate.toIso8601String(),
    totalDrivers: drivers.length,
  );
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Overview report — tries Firebase Functions first, falls back to Firestore.
final overviewReportProvider = FutureProvider<OverviewReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  // Try Firebase Functions
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getReportsOverview');
    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
    });
    if (result.data.isNotEmpty) {
      return OverviewReportData.fromJson(result.data);
    }
  } catch (e) {
    if (kDebugMode) print('Functions unavailable, using Firestore: $e');
  }

  // Firestore fallback
  try {
    return await _fetchOverviewFromFirestore(filter);
  } catch (e) {
    if (kDebugMode) print('Firestore fallback error: $e');
    rethrow;
  }
});

/// Financial report — tries Firebase Functions first, falls back to Firestore.
final financialReportProvider =
    FutureProvider<FinancialReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getFinancialReport');
    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
    });
    if (result.data.isNotEmpty) {
      return FinancialReportData.fromJson(result.data);
    }
  } catch (e) {
    if (kDebugMode) print('Functions unavailable, using Firestore: $e');
  }

  try {
    return await _fetchFinancialFromFirestore(filter);
  } catch (e) {
    if (kDebugMode) print('Firestore fallback error: $e');
    rethrow;
  }
});

/// Driver performance report — tries Firebase Functions first, falls back to Firestore.
final driverPerformanceReportProvider =
    FutureProvider<DriverPerformanceReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('getDriverPerformanceReport');
    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      'limit': 50,
    });
    if (result.data.isNotEmpty) {
      return DriverPerformanceReportData.fromJson(result.data);
    }
  } catch (e) {
    if (kDebugMode) print('Functions unavailable, using Firestore: $e');
  }

  try {
    return await _fetchDriverPerfFromFirestore(filter);
  } catch (e) {
    if (kDebugMode) print('Firestore fallback error: $e');
    rethrow;
  }
});
