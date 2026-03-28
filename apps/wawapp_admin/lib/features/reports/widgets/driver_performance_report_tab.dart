import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../core/theme/colors.dart';
import '../../../providers/reports_providers.dart';
import '../utils/csv_export.dart';

enum DriverSortBy { earnings, trips, rating }

final driverSortByProvider = StateProvider<DriverSortBy>((ref) => DriverSortBy.earnings);

class DriverPerformanceReportTab extends ConsumerWidget {
  const DriverPerformanceReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(driverPerformanceReportProvider);
    final sortBy = ref.watch(driverSortByProvider);

    return reportAsync.when(
      data: (data) {
        if (data == null) {
          return _buildEmptyState(context);
        }
        return _buildContent(context, ref, data, sortBy);
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, data, DriverSortBy sortBy) {
    // Sort drivers based on selected criterion
    final sortedDrivers = List.from(data.drivers);
    switch (sortBy) {
      case DriverSortBy.earnings:
        sortedDrivers.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
        break;
      case DriverSortBy.trips:
        sortedDrivers.sort((a, b) => b.totalTrips.compareTo(a.totalTrips));
        break;
      case DriverSortBy.rating:
        sortedDrivers.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export button and sort tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Sort tabs
              Row(
                children: [
                  Text(
                    'ترتيب حسب: ',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  SizedBox(width: AdminSpacing.sm),
                  _buildSortTab(
                    context: context,
                    ref: ref,
                    label: 'الأرباح',
                    sortBy: DriverSortBy.earnings,
                    currentSort: sortBy,
                  ),
                  SizedBox(width: AdminSpacing.xs),
                  _buildSortTab(
                    context: context,
                    ref: ref,
                    label: 'الرحلات',
                    sortBy: DriverSortBy.trips,
                    currentSort: sortBy,
                  ),
                  SizedBox(width: AdminSpacing.xs),
                  _buildSortTab(
                    context: context,
                    ref: ref,
                    label: 'التقييم',
                    sortBy: DriverSortBy.rating,
                    currentSort: sortBy,
                  ),
                ],
              ),
              // Export buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => CsvExportUtil.exportDriverPerformanceReport(data),
                    icon: const Icon(Icons.file_download),
                    label: const Text('تصدير CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminAppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(width: AdminSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => _printReport(),
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AdminAppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Summary info
          Container(
            padding: EdgeInsets.all(AdminSpacing.md),
            decoration: BoxDecoration(
              color: AdminAppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
              border: Border.all(color: AdminAppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Text(
              'إجمالي السائقين: ${data.totalDrivers} | عرض أفضل ${sortedDrivers.length} سائق',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AdminAppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),

          SizedBox(height: AdminSpacing.lg),

          // Driver Performance Table
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
              border: Border.all(color: AdminAppColors.borderLight),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(
                  AdminAppColors.backgroundLight,
                ),
                columns: const [
                  DataColumn(label: Text('الرقم')),
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('الهاتف')),
                  DataColumn(label: Text('المشغل')),
                  DataColumn(label: Text('إجمالي الرحلات')),
                  DataColumn(label: Text('رحلات مكتملة')),
                  DataColumn(label: Text('إجمالي الأرباح')),
                  DataColumn(label: Text('التقييم')),
                  DataColumn(label: Text('معدل الإلغاء')),
                ],
                rows: sortedDrivers.asMap().entries.map<DataRow>((entry) {
                  final index = entry.key + 1;
                  final driver = entry.value;

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AdminSpacing.sm,
                            vertical: AdminSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getRankColor(index),
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                          ),
                          child: Text(
                            '#$index',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          driver.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(driver.phone)),
                      DataCell(
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AdminSpacing.sm,
                            vertical: AdminSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _getOperatorColor(driver.operator).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                            border: Border.all(
                              color: _getOperatorColor(driver.operator),
                            ),
                          ),
                          child: Text(
                            driver.operator,
                            style: TextStyle(
                              color: _getOperatorColor(driver.operator),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(driver.totalTrips.toString())),
                      DataCell(Text(driver.completedTrips.toString())),
                      DataCell(
                        Text(
                          '${_formatCurrency(driver.totalEarnings)} MRU',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              driver.averageRating.toStringAsFixed(1),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          '${driver.cancellationRate}%',
                          style: TextStyle(
                            color: driver.cancellationRate > 20 ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortTab({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required DriverSortBy sortBy,
    required DriverSortBy currentSort,
  }) {
    final isSelected = sortBy == currentSort;

    return Material(
      color: isSelected
          ? AdminAppColors.primaryGreen
          : AdminAppColors.backgroundLight,
      borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      child: InkWell(
        onTap: () => ref.read(driverSortByProvider.notifier).state = sortBy,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AdminSpacing.md,
            vertical: AdminSpacing.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isSelected ? Colors.white : AdminAppColors.textPrimaryLight,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey[400]!;
    if (rank == 3) return Colors.brown[300]!;
    return AdminAppColors.primaryGreen;
  }

  Color _getOperatorColor(String operator) {
    switch (operator) {
      case 'Chinguitel':
        return Colors.blue;
      case 'Mattel':
        return Colors.orange;
      case 'Mauritel':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat('#,###');
    return formatter.format(amount);
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          SizedBox(height: AdminSpacing.md),
          Text(
            'خطأ في تحميل البيانات',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AdminSpacing.sm),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: AdminAppColors.textSecondaryLight,
          ),
          SizedBox(height: AdminSpacing.md),
          Text(
            'لا توجد بيانات أداء متاحة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  void _printReport() {
    // Trigger browser print dialog
    html.window.print();
  }
}
