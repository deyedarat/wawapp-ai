import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/reports_providers.dart';
import '../utils/csv_export.dart';

class FinancialReportTab extends ConsumerWidget {
  const FinancialReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(financialReportProvider);

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
                onPressed: () => CsvExportUtil.exportFinancialReport(data),
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

          // Financial Summary Cards
          Text(
            'الملخص المالي',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: AdminSpacing.md),

          // Orders-based Metrics
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AdminSpacing.md,
            crossAxisSpacing: AdminSpacing.md,
            childAspectRatio: 2.5,
            children: [
              _buildSummaryCard(
                context: context,
                title: 'إجمالي الإيرادات',
                value: '${_formatCurrency(data.summary.grossRevenue)} MRU',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              _buildSummaryCard(
                context: context,
                title: 'أرباح السائقين',
                value: '${_formatCurrency(data.summary.totalDriverEarnings)} MRU',
                icon: Icons.people,
                color: Colors.blue,
              ),
              _buildSummaryCard(
                context: context,
                title: 'عمولة المنصة',
                value: '${_formatCurrency(data.summary.totalPlatformCommission)} MRU',
                icon: Icons.account_balance,
                color: Colors.orange,
              ),
              _buildSummaryCard(
                context: context,
                title: 'عدد الطلبات',
                value: data.summary.totalOrders.toString(),
                icon: Icons.shopping_bag,
                color: AdminAppColors.primaryGreen,
              ),
              _buildSummaryCard(
                context: context,
                title: 'معدل العمولة',
                value: '${data.summary.averageCommissionRate}%',
                icon: Icons.percent,
                color: Colors.purple,
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.xl),

          // Wallet & Payout Metrics
          Text(
            'مؤشرات المحافظ والدفعات',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: AdminSpacing.md),

          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AdminSpacing.md,
            crossAxisSpacing: AdminSpacing.md,
            childAspectRatio: 2.5,
            children: [
              _buildSummaryCard(
                context: context,
                title: 'المدفوعات المكتملة',
                value: '${_formatCurrency(data.summary.totalPayoutsInPeriod)} MRU',
                icon: Icons.payment,
                color: Color(0xFF9C27B0), // Purple
              ),
              _buildSummaryCard(
                context: context,
                title: 'أرصدة السائقين المعلقة',
                value: '${_formatCurrency(data.summary.totalDriverOutstandingBalance)} MRU',
                icon: Icons.account_balance_wallet,
                color: Color(0xFFFF9800), // Orange
              ),
              _buildSummaryCard(
                context: context,
                title: 'رصيد محفظة المنصة',
                value: '${_formatCurrency(data.summary.platformWalletBalance)} MRU',
                icon: Icons.business,
                color: Color(0xFF00BCD4), // Cyan
              ),
            ],
          ),

          SizedBox(height: AdminSpacing.xl),

          // Daily Breakdown Table
          Text(
            'التفصيل اليومي',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: AdminSpacing.md),

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
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('عدد الطلبات')),
                  DataColumn(label: Text('إجمالي الإيرادات')),
                  DataColumn(label: Text('أرباح السائقين')),
                  DataColumn(label: Text('عمولة المنصة')),
                ],
                rows: data.dailyBreakdown.map<DataRow>((day) {
                  final date = DateTime.parse(day.date);
                  final dateFormat = DateFormat('dd/MM/yyyy');

                  return DataRow(cells: [
                    DataCell(Text(dateFormat.format(date))),
                    DataCell(Text(day.ordersCount.toString())),
                    DataCell(Text('${_formatCurrency(day.grossRevenue)} MRU')),
                    DataCell(Text('${_formatCurrency(day.driverEarnings)} MRU')),
                    DataCell(Text('${_formatCurrency(day.platformCommission)} MRU')),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
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
              Icon(icon, color: color, size: 28),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
            'لا توجد بيانات مالية متاحة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  void _printReport() {
    // Trigger browser print dialog
    // ignore: avoid_web_libraries_in_flutter
    import 'dart:html' as html;
    html.window.print();
  }
}
