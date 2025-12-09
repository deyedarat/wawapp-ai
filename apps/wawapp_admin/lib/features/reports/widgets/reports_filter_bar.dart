import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';
import '../../../providers/reports_providers.dart';
import '../models/reports_filter_state.dart';

class ReportsFilterBar extends ConsumerWidget {
  const ReportsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(reportsFilterProvider);

    return Container(
      padding: EdgeInsets.all(AdminSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: AdminAppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          // Time window selector
          _buildTimeWindowChips(context, ref, filter),

          SizedBox(width: AdminSpacing.lg),

          // Date range display
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: AdminSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AdminAppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
              border: Border.all(color: AdminAppColors.primaryGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: AdminAppColors.primaryGreen,
                ),
                SizedBox(width: AdminSpacing.sm),
                Text(
                  _formatDateRange(filter),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AdminAppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Custom date picker button
          OutlinedButton.icon(
            onPressed: () => _showCustomDatePicker(context, ref, filter),
            icon: const Icon(Icons.date_range),
            label: const Text('نطاق مخصص'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminAppColors.primaryGreen,
              side: BorderSide(color: AdminAppColors.primaryGreen.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeWindowChips(
    BuildContext context,
    WidgetRef ref,
    ReportsFilterState filter,
  ) {
    return Wrap(
      spacing: AdminSpacing.sm,
      children: [
        _buildFilterChip(
          context: context,
          label: 'اليوم',
          isSelected: filter.timeWindow == TimeWindow.today,
          onTap: () => ref.read(reportsFilterProvider.notifier).state =
              ReportsFilterState.today(),
        ),
        _buildFilterChip(
          context: context,
          label: 'آخر 7 أيام',
          isSelected: filter.timeWindow == TimeWindow.last7Days,
          onTap: () => ref.read(reportsFilterProvider.notifier).state =
              ReportsFilterState.last7Days(),
        ),
        _buildFilterChip(
          context: context,
          label: 'آخر 30 يوم',
          isSelected: filter.timeWindow == TimeWindow.last30Days,
          onTap: () => ref.read(reportsFilterProvider.notifier).state =
              ReportsFilterState.last30Days(),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? AdminAppColors.primaryGreen
          : AdminAppColors.backgroundLight,
      borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      child: InkWell(
        onTap: onTap,
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

  String _formatDateRange(ReportsFilterState filter) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    return '${dateFormat.format(filter.startDate)} - ${dateFormat.format(filter.endDate)}';
  }

  void _showCustomDatePicker(
    BuildContext context,
    WidgetRef ref,
    ReportsFilterState filter,
  ) async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: filter.startDate,
        end: filter.endDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AdminAppColors.primaryGreen,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      ref.read(reportsFilterProvider.notifier).state =
          ReportsFilterState.custom(
        startDate: dateRange.start,
        endDate: dateRange.end,
      );
    }
  }
}
