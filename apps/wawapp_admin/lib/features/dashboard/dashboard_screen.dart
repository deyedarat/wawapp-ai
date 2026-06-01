import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/audit_log_service.dart';

/// Provider for recent activity from audit log
final recentActivityProvider = StreamProvider<List<AuditLogEntry>>((ref) {
  final service = AuditLogService();
  return service.getRecentActivity(limit: 10);
});

/// Provider for recent orders activity (real-time)
final recentOrdersActivityProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .orderBy('updatedAt', descending: true)
      .limit(8)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList(),
      );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return AdminScaffold(
      title: 'لوحة التحكم',
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('خطأ في تحميل البيانات: $error'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => ref.refresh(dashboardStatsProvider), child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
        data: (stats) {
          final orderStats = stats['orders'] as Map<String, int>? ?? {};
          final driverStats = stats['drivers'] as Map<String, int>? ?? {};

          final totalDrivers = driverStats['total'] ?? 0;
          final onlineDrivers = driverStats['online'] ?? 0;
          final activeOrders =
              (orderStats['assigning'] ?? 0) + (orderStats['accepted'] ?? 0) + (orderStats['on_route'] ?? 0);
          final completedToday = orderStats['completed'] ?? 0;
          final cancelledToday = orderStats['cancelled'] ?? 0;

          final onlinePercent = totalDrivers > 0 ? (onlineDrivers / totalDrivers * 100).toInt() : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats grid
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'السائقون النشطون',
                        value: '$onlineDrivers',
                        icon: Icons.drive_eta,
                        color: AdminAppColors.onlineGreen,
                        subtitle: '$onlinePercent٪ متصلون',
                        onTap: () => context.go('/drivers'),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'الطلبات الجارية',
                        value: '$activeOrders',
                        icon: Icons.local_shipping,
                        color: AdminAppColors.activeBlue,
                        subtitle: 'قيد التوصيل',
                        onTap: () => context.go('/orders'),
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'طلبات اليوم',
                        value: '$completedToday',
                        icon: Icons.check_circle,
                        color: AdminAppColors.successLight,
                        subtitle: 'مكتملة',
                      ),
                    ),
                    const SizedBox(width: AdminSpacing.md),
                    Expanded(
                      child: StatCard(
                        title: 'طلبات ملغاة',
                        value: '$cancelledToday',
                        icon: Icons.cancel,
                        color: AdminAppColors.errorLight,
                        subtitle: 'اليوم',
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: AdminSpacing.xl),

              // Real-time recent activity section
              Text('النشاط الأخير', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: AdminSpacing.md),

              _buildRecentActivityCard(context, ref),

              SizedBox(height: AdminSpacing.xl),

              // Quick actions
              Row(
                children: [Expanded(child: Text('إجراءات سريعة', style: Theme.of(context).textTheme.titleLarge))],
              ),
              SizedBox(height: AdminSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.local_shipping,
                      title: 'إنشاء طلب',
                      color: AdminAppColors.primaryGreen,
                      onTap: () => context.go('/orders'),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.map,
                      title: 'المراقبة الحية',
                      color: AdminAppColors.activeBlue,
                      onTap: () => context.go('/live-ops'),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.bar_chart,
                      title: 'التقارير',
                      color: AdminAppColors.goldenYellow,
                      onTap: () => context.go('/reports'),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      icon: Icons.settings,
                      title: 'الإعدادات',
                      color: AdminAppColors.textSecondaryLight,
                      onTap: () => context.go('/settings'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds real-time activity card from recent orders
  Widget _buildRecentActivityCard(BuildContext context, WidgetRef ref) {
    final recentOrdersAsync = ref.watch(recentOrdersActivityProvider);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AdminSpacing.lg),
        child: recentOrdersAsync.when(
          loading: () => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
          ),
          error: (_, __) => const Center(
            child: Padding(padding: EdgeInsets.all(24), child: Text('تعذّر تحميل النشاط الأخير')),
          ),
          data: (orders) {
            if (orders.isEmpty) {
              return const Center(
                child: Padding(padding: EdgeInsets.all(24), child: Text('لا يوجد نشاط حديث')),
              );
            }

            return Column(
              children: orders.take(5).map((order) {
                final status = order['status'] as String? ?? 'unknown';
                final id = (order['id'] as String? ?? '').length > 8
                    ? (order['id'] as String).substring(0, 8).toUpperCase()
                    : order['id'] ?? '';
                final pickup = order['pickupAddress'] as String? ?? '';
                final dropoff = order['dropoffAddress'] as String? ?? '';
                final updatedAt = order['updatedAt'];

                return Column(
                  children: [
                    _buildActivityItem(
                      context,
                      icon: _getStatusIcon(status),
                      color: _getStatusColor(status),
                      title: '${_getStatusLabel(status)} — #$id',
                      subtitle: pickup.isNotEmpty && dropoff.isNotEmpty ? '$pickup → $dropoff' : 'طلب بدون عنوان',
                      time: _formatTimestamp(updatedAt),
                    ),
                    if (orders.indexOf(order) < 4) Divider(height: AdminSpacing.lg),
                  ],
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'assigning':
      case 'matching':
        return Icons.search;
      case 'accepted':
        return Icons.check_circle;
      case 'on_route':
        return Icons.local_shipping;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
      case 'cancelled_by_admin':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigning':
      case 'matching':
        return AdminAppColors.goldenYellow;
      case 'accepted':
        return AdminAppColors.activeBlue;
      case 'on_route':
        return AdminAppColors.onlineGreen;
      case 'completed':
        return AdminAppColors.successLight;
      case 'cancelled':
      case 'cancelled_by_admin':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
        return AdminAppColors.errorLight;
      default:
        return AdminAppColors.textSecondaryLight;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'assigning':
      case 'matching':
        return 'قيد التعيين';
      case 'accepted':
        return 'تم القبول';
      case 'on_route':
        return 'في الطريق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'cancelled_by_admin':
      case 'cancelled_by_driver':
      case 'cancelled_by_client':
        return 'ملغى';
      default:
        return status;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return DateFormat('MM/dd HH:mm', 'en').format(date);
  }

  Widget _buildActivityItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AdminSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        SizedBox(width: AdminSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              SizedBox(height: AdminSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Text(time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminAppColors.textSecondaryLight)),
      ],
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
        child: Padding(
          padding: EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            children: [
              Icon(icon, color: color, size: 36),
              SizedBox(height: AdminSpacing.sm),
              Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
