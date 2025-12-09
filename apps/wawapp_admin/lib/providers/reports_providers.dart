import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reports/models/reports_filter_state.dart';
import '../features/reports/models/report_models.dart';

/// Reports filter state provider
final reportsFilterProvider = StateProvider<ReportsFilterState>((ref) {
  return ReportsFilterState.last7Days();
});

/// Overview report provider
final overviewReportProvider = FutureProvider<OverviewReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  try {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('getReportsOverview');

    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
    });

    if (result.data == null) return null;

    return OverviewReportData.fromJson(result.data);
  } catch (e) {
    print('Error fetching overview report: $e');
    rethrow;
  }
});

/// Financial report provider
final financialReportProvider = FutureProvider<FinancialReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  try {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('getFinancialReport');

    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
    });

    if (result.data == null) return null;

    return FinancialReportData.fromJson(result.data);
  } catch (e) {
    print('Error fetching financial report: $e');
    rethrow;
  }
});

/// Driver performance report provider
final driverPerformanceReportProvider =
    FutureProvider<DriverPerformanceReportData?>((ref) async {
  final filter = ref.watch(reportsFilterProvider);

  try {
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('getDriverPerformanceReport');

    final result = await callable.call<Map<String, dynamic>>({
      'startDate': filter.startDate.toIso8601String(),
      'endDate': filter.endDate.toIso8601String(),
      'limit': 50,
    });

    if (result.data == null) return null;

    return DriverPerformanceReportData.fromJson(result.data);
  } catch (e) {
    print('Error fetching driver performance report: $e');
    rethrow;
  }
});
