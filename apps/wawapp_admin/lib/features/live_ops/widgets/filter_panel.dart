/**
 * Filter Panel Widget
 * Side panel with filters and controls for Live Operations
 */

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../models/live_ops_filters.dart';
import '../providers/live_ops_providers.dart';

class FilterPanel extends ConsumerWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(liveOpsFiltersProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: AdminAppColors.surfaceLight,
        border: Border(
          right: BorderSide(
            color: AdminAppColors.borderLight,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.all(AdminSpacing.lg),
        children: [
          // Header
          Text(
            'الفلاتر والخيارات',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AdminSpacing.md),

          // Driver Status Filter
          _buildFilterSection(
            context,
            title: 'حالة السائق',
            child: Column(
              children: [
                _buildRadioTile<DriverStatusFilter>(
                  context,
                  ref,
                  title: 'الكل',
                  value: DriverStatusFilter.all,
                  groupValue: filters.driverStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(driverStatus: value);
                  },
                ),
                _buildRadioTile<DriverStatusFilter>(
                  context,
                  ref,
                  title: 'متصلون فقط',
                  value: DriverStatusFilter.onlineOnly,
                  groupValue: filters.driverStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(driverStatus: value);
                  },
                ),
                _buildRadioTile<DriverStatusFilter>(
                  context,
                  ref,
                  title: 'غير متصلين',
                  value: DriverStatusFilter.offlineOnly,
                  groupValue: filters.driverStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(driverStatus: value);
                  },
                ),
                _buildRadioTile<DriverStatusFilter>(
                  context,
                  ref,
                  title: 'محظورون',
                  value: DriverStatusFilter.blockedOnly,
                  groupValue: filters.driverStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(driverStatus: value);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: AdminSpacing.lg),

          // Operator Filter
          _buildFilterSection(
            context,
            title: 'المشغل',
            child: Column(
              children: [
                _buildRadioTile<OperatorFilter>(
                  context,
                  ref,
                  title: 'الكل',
                  value: OperatorFilter.all,
                  groupValue: filters.operator,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(operator: value);
                  },
                ),
                _buildRadioTile<OperatorFilter>(
                  context,
                  ref,
                  title: 'موريتل',
                  value: OperatorFilter.mauritel,
                  groupValue: filters.operator,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(operator: value);
                  },
                ),
                _buildRadioTile<OperatorFilter>(
                  context,
                  ref,
                  title: 'شنقيتل',
                  value: OperatorFilter.chinguitel,
                  groupValue: filters.operator,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(operator: value);
                  },
                ),
                _buildRadioTile<OperatorFilter>(
                  context,
                  ref,
                  title: 'ماتل',
                  value: OperatorFilter.mattel,
                  groupValue: filters.operator,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(operator: value);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: AdminSpacing.lg),

          // Order Status Filter
          _buildFilterSection(
            context,
            title: 'حالة الطلب',
            child: Column(
              children: [
                _buildRadioTile<OrderStatusFilter>(
                  context,
                  ref,
                  title: 'الكل',
                  value: OrderStatusFilter.all,
                  groupValue: filters.orderStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(orderStatus: value);
                  },
                ),
                _buildRadioTile<OrderStatusFilter>(
                  context,
                  ref,
                  title: 'قيد التعيين',
                  value: OrderStatusFilter.assigning,
                  groupValue: filters.orderStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(orderStatus: value);
                  },
                ),
                _buildRadioTile<OrderStatusFilter>(
                  context,
                  ref,
                  title: 'مقبول',
                  value: OrderStatusFilter.accepted,
                  groupValue: filters.orderStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(orderStatus: value);
                  },
                ),
                _buildRadioTile<OrderStatusFilter>(
                  context,
                  ref,
                  title: 'في الطريق',
                  value: OrderStatusFilter.onRoute,
                  groupValue: filters.orderStatus,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(orderStatus: value);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: AdminSpacing.lg),

          // Time Window Filter
          _buildFilterSection(
            context,
            title: 'الإطار الزمني',
            child: Column(
              children: [
                _buildRadioTile<TimeWindowFilter>(
                  context,
                  ref,
                  title: 'الآن (نشطة فقط)',
                  value: TimeWindowFilter.now,
                  groupValue: filters.timeWindow,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(timeWindow: value);
                  },
                ),
                _buildRadioTile<TimeWindowFilter>(
                  context,
                  ref,
                  title: 'آخر ساعة',
                  value: TimeWindowFilter.lastHour,
                  groupValue: filters.timeWindow,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(timeWindow: value);
                  },
                ),
                _buildRadioTile<TimeWindowFilter>(
                  context,
                  ref,
                  title: 'اليوم',
                  value: TimeWindowFilter.today,
                  groupValue: filters.timeWindow,
                  onChanged: (value) {
                    ref.read(liveOpsFiltersProvider.notifier).state =
                        filters.copyWith(timeWindow: value);
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: AdminSpacing.lg),

          // Anomaly Toggle
          CheckboxListTile(
            title: Text(
              'عرض الحالات الشاذة فقط',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            subtitle: Text(
              'طلبات عالقة أكثر من 10 دقائق',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            value: filters.showAnomaliesOnly,
            onChanged: (value) {
              ref.read(liveOpsFiltersProvider.notifier).state =
                  filters.copyWith(showAnomaliesOnly: value ?? false);
            },
            activeColor: AdminAppColors.primaryLight,
          ),

          SizedBox(height: AdminSpacing.lg),

          // Reset Button
          if (!filters.isDefault)
            ElevatedButton.icon(
              onPressed: () {
                ref.read(liveOpsFiltersProvider.notifier).state =
                    const LiveOpsFilters();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة تعيين الفلاتر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminAppColors.textSecondaryLight,
                padding: EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                  vertical: AdminSpacing.sm,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AdminAppColors.primaryLight,
          ),
        ),
        SizedBox(height: AdminSpacing.sm),
        Card(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: AdminSpacing.xs),
            child: child,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioTile<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return RadioListTile<T>(
      title: Text(title),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AdminAppColors.primaryLight,
      dense: true,
    );
  }
}
