import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../../core/theme/colors.dart';
import '../../../providers/reports_providers.dart';
import '../utils/csv_export.dart';

class OverviewReportTab extends ConsumerWidget {
  const OverviewReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(overviewReportProvider);

    return reportAsync.when(
      data: (data) {
        if (data == null) {
          return _buildEmptyState(context);
        }
        return _buildContent(context, data);
      },
      loading: () => _buildLoadingState(),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  Widget _buildContent(BuildContext context, data) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AdminSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => CsvExportUtil.exportOverviewReport(data),
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

          SizedBox(height: AdminSpacing.lg),

          // KPI Cards Grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AdminSpacing.md,
            crossAxisSpacing: AdminSpacing.md,
            childAspectRatio: 2.0,
            children: [
              _buildKpiCard(
                context: context,
                title: 'إجمالي الطلبات',
                value: data.totalOrders.toString(),
                icon: Icons.local_shipping,
                color: AdminAppColors.primaryGreen,
              ),
              _buildKpiCard(
                context: context,
                title: 'الطلبات المكتملة',
                value: data.completedOrders.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildKpiCard(
                context: context,
                title: 'الطلبات الملغاة',
                value: data.cancelledOrders.toString(),
                icon: Icons.cancel,
                color: Colors.red,
              ),
              _buildKpiCard(
                context: context,
                title: 'معدل الإنجاز',
                value: '${data.completionRate}%',
                icon: Icons.trending_up,
                color: Colors.blue,
              ),
              _buildKpiCard(
                context: context,
                title: 'متوسط قيمة الطلب',
                value: '${data.averageOrderValue} MRU',
                icon: Icons.attach_money,
                color: Colors.orange,
              ),
              _buildKpiCard(
                context: context,
                title: 'السائقون النشطون',
                value: data.totalActiveDrivers.toString(),
                icon: Icons.drive_eta,
                color: AdminAppColors.accentBlue,
              ),
              _buildKpiCard(
                context: context,
                title: 'عملاء جدد',
                value: data.newClients.toString(),
                icon: Icons.person_add,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        border: Border.all(color: AdminAppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: AdminSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AdminAppColors.textSecondaryLight,
                ),
          ),
        ],
      ),
    );
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
            'لا توجد بيانات متاحة',
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
