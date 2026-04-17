import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/stat_card.dart';

// =============================================================================
// Model
// =============================================================================

class NotificationAnalytics {
  const NotificationAnalytics({
    required this.date,
    required this.totalSent,
    required this.totalDelivered,
    required this.totalTapped,
    required this.totalDuplicates,
    required this.deliveryRate,
    required this.tapRate,
    required this.duplicateRate,
    required this.byType,
  });

  final String date;
  final int totalSent;
  final int totalDelivered;
  final int totalTapped;
  final int totalDuplicates;
  final double deliveryRate;
  final double tapRate;
  final double duplicateRate;
  final Map<String, TypeMetrics> byType;

  factory NotificationAnalytics.fromFirestore(Map<String, dynamic> data) {
    final rawByType = data['byType'] as Map<String, dynamic>? ?? {};
    final byType = rawByType.map((key, value) {
      final m = value as Map<String, dynamic>;
      return MapEntry(key, TypeMetrics(
        sent: (m['sent'] as num?)?.toInt() ?? 0,
        delivered: (m['delivered'] as num?)?.toInt() ?? 0,
        tapped: (m['tapped'] as num?)?.toInt() ?? 0,
        duplicates: (m['duplicates'] as num?)?.toInt() ?? 0,
      ));
    });

    return NotificationAnalytics(
      date: data['date'] as String? ?? '',
      totalSent: (data['totalSent'] as num?)?.toInt() ?? 0,
      totalDelivered: (data['totalDelivered'] as num?)?.toInt() ?? 0,
      totalTapped: (data['totalTapped'] as num?)?.toInt() ?? 0,
      totalDuplicates: (data['totalDuplicates'] as num?)?.toInt() ?? 0,
      deliveryRate: (data['deliveryRate'] as num?)?.toDouble() ?? 0,
      tapRate: (data['tapRate'] as num?)?.toDouble() ?? 0,
      duplicateRate: (data['duplicateRate'] as num?)?.toDouble() ?? 0,
      byType: byType,
    );
  }
}

class TypeMetrics {
  const TypeMetrics({
    required this.sent,
    required this.delivered,
    required this.tapped,
    required this.duplicates,
  });

  final int sent;
  final int delivered;
  final int tapped;
  final int duplicates;

  double get tapRate => delivered > 0 ? tapped / delivered * 100 : 0;
}

// =============================================================================
// Provider
// =============================================================================

final _selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now().subtract(const Duration(days: 1));
});

final notificationAnalyticsProvider =
    FutureProvider.autoDispose<NotificationAnalytics?>((ref) async {
  final date = ref.watch(_selectedDateProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(date);

  final doc = await FirebaseFirestore.instance
      .collection('notification_analytics')
      .doc(dateStr)
      .get();

  if (!doc.exists) return null;
  return NotificationAnalytics.fromFirestore(doc.data()!);
});

// =============================================================================
// Screen
// =============================================================================

class NotificationAnalyticsScreen extends ConsumerWidget {
  const NotificationAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(notificationAnalyticsProvider);
    final selectedDate = ref.watch(_selectedDateProvider);

    return AdminScaffold(
      title: 'تحليلات الإشعارات',
      actions: [
        TextButton.icon(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 90)),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              ref.read(_selectedDateProvider.notifier).state = picked;
            }
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(notificationAnalyticsProvider),
          tooltip: 'تحديث',
        ),
      ],
      child: analyticsAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(64),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('خطأ: $e'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(notificationAnalyticsProvider),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
        data: (analytics) {
          if (analytics == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(64),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, size: 64,
                        color: AdminAppColors.textSecondaryLight.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد بيانات لـ ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                      style: TextStyle(color: AdminAppColors.textSecondaryLight),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'يتم تجميع البيانات يومياً الساعة 2:00 صباحاً',
                      style: TextStyle(
                        fontSize: 12,
                        color: AdminAppColors.textSecondaryLight.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Summary cards ──
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'معدل التوصيل',
                        value: '${analytics.deliveryRate.toStringAsFixed(1)}٪',
                        icon: Icons.send,
                        color: AdminAppColors.successLight,
                        subtitle: '${analytics.totalDelivered} / ${analytics.totalSent}',
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'معدل النقر',
                        value: '${analytics.tapRate.toStringAsFixed(1)}٪',
                        icon: Icons.touch_app,
                        color: AdminAppColors.activeBlue,
                        subtitle: '${analytics.totalTapped} نقرة',
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'معدل التكرار',
                        value: '${analytics.duplicateRate.toStringAsFixed(1)}٪',
                        icon: Icons.content_copy,
                        color: analytics.duplicateRate > 5
                            ? AdminAppColors.errorLight
                            : AdminAppColors.warningLight,
                        subtitle: '${analytics.totalDuplicates} مكرر',
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'إجمالي الإرسال',
                        value: '${analytics.totalSent}',
                        icon: Icons.notifications_active,
                        color: AdminAppColors.primaryGreen,
                        subtitle: analytics.date,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AdminSpacing.xl),

              // ── Per-type breakdown ──
              Text('تفصيل حسب النوع',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AdminSpacing.md),

              if (analytics.byType.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('لا توجد بيانات تفصيلية')),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                        3: FlexColumnWidth(1),
                        4: FlexColumnWidth(1),
                        5: FlexColumnWidth(1),
                      },
                      children: [
                        _buildHeaderRow(),
                        ...analytics.byType.entries.map(
                          (e) => _buildTypeRow(e.key, e.value),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  TableRow _buildHeaderRow() {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 13,
      color: AdminAppColors.textSecondaryLight,
    );
    return const TableRow(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
      ),
      children: [
        Padding(padding: EdgeInsets.all(12), child: Text('النوع', style: style)),
        Padding(padding: EdgeInsets.all(12), child: Text('مُرسل', style: style)),
        Padding(padding: EdgeInsets.all(12), child: Text('مُوصل', style: style)),
        Padding(padding: EdgeInsets.all(12), child: Text('نقرات', style: style)),
        Padding(padding: EdgeInsets.all(12), child: Text('مكرر', style: style)),
        Padding(padding: EdgeInsets.all(12), child: Text('معدل النقر', style: style)),
      ],
    );
  }

  TableRow _buildTypeRow(String type, TypeMetrics m) {
    final tapRateStr = '${m.tapRate.toStringAsFixed(1)}٪';
    final tapColor = m.tapRate > 30
        ? AdminAppColors.successLight
        : m.tapRate > 10
            ? AdminAppColors.warningLight
            : AdminAppColors.errorLight;

    const cellStyle = TextStyle(fontSize: 13);

    return TableRow(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AdminAppColors.borderLight, width: 0.5)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_localizeType(type), style: cellStyle),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Text('${m.sent}', style: cellStyle)),
        Padding(padding: const EdgeInsets.all(12), child: Text('${m.delivered}', style: cellStyle)),
        Padding(padding: const EdgeInsets.all(12), child: Text('${m.tapped}', style: cellStyle)),
        Padding(padding: const EdgeInsets.all(12), child: Text('${m.duplicates}', style: cellStyle)),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tapColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tapRateStr,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tapColor),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  String _localizeType(String type) {
    switch (type) {
      case 'new_order':
        return 'طلب جديد';
      case 'new_order_nearby':
        return 'طلب قريب';
      case 'unassigned_order_reminder':
        return 'تذكير طلب متاح';
      case 'trip_start_reminder':
        return 'تذكير بدء الرحلة';
      case 'wave_offer':
        return 'عرض موجة';
      case 'acceptance_confirmation':
        return 'تأكيد القبول';
      case 'order_update':
        return 'تحديث الطلب';
      case 'order_cancelled':
        return 'طلب ملغى';
      case 'timeout_expired':
        return 'انتهاء المهلة';
      default:
        return type;
    }
  }
}
