import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/animations.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/gradient_card.dart';
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
              (orderStats['matching'] ?? 0) + (orderStats['accepted'] ?? 0) + (orderStats['onRoute'] ?? 0);
          final completedToday = orderStats['completed'] ?? 0;
          final cancelledToday = orderStats['cancelled'] ?? 0;

          final onlinePercent = totalDrivers > 0 ? (onlineDrivers / totalDrivers * 100).toInt() : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome gradient card
              GradientCard.primary(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مرحباً بك في لوحة التحكم',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AdminSpacing.xs),
                          Text(
                            'إليك ملخص نشاط اليوم',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AdminSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${completedToday + activeOrders}',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'طلب اليوم',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AdminSpacing.lg),

              // Summary stats grid — responsive
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;

                  if (isMobile) {
                    return Column(
                      children: [
                        Row(
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
                            const SizedBox(width: AdminSpacing.sm),
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
                          ],
                        ),
                        const SizedBox(height: AdminSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'طلبات اليوم',
                                value: '$completedToday',
                                icon: Icons.check_circle,
                                color: AdminAppColors.successLight,
                                subtitle: 'مكتملة',
                              ),
                            ),
                            const SizedBox(width: AdminSpacing.sm),
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
                      ],
                    );
                  }

                  return IntrinsicHeight(
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
                  );
                },
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

              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    return GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: AdminSpacing.sm,
                      mainAxisSpacing: AdminSpacing.sm,
                      childAspectRatio: 1.3,
                      children: [
                        _buildQuickActionCard(
                          context,
                          icon: Icons.local_shipping,
                          title: 'إنشاء طلب',
                          color: AdminAppColors.primaryGreen,
                          onTap: () => context.go('/orders'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.map,
                          title: 'المراقبة الحية',
                          color: AdminAppColors.activeBlue,
                          onTap: () => context.go('/live-ops'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.bar_chart,
                          title: 'التقارير',
                          color: AdminAppColors.goldenYellow,
                          onTap: () => context.go('/reports'),
                        ),
                        _buildQuickActionCard(
                          context,
                          icon: Icons.settings,
                          title: 'الإعدادات',
                          color: AdminAppColors.textSecondaryLight,
                          onTap: () => context.go('/settings'),
                        ),
                      ],
                    );
                  }

                  return Row(
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
                  );
                },
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
      case 'matching':
        return Icons.search;
      case 'accepted':
        return Icons.check_circle;
      case 'onRoute':
        return Icons.local_shipping;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
      case 'cancelledByAdmin':
      case 'cancelled_by_admin':
      case 'cancelledByDriver':
      case 'cancelledByClient':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'matching':
        return AdminAppColors.goldenYellow;
      case 'accepted':
        return AdminAppColors.activeBlue;
      case 'onRoute':
        return AdminAppColors.onlineGreen;
      case 'completed':
        return AdminAppColors.successLight;
      case 'cancelled':
      case 'cancelledByAdmin':
      case 'cancelled_by_admin':
      case 'cancelledByDriver':
      case 'cancelledByClient':
        return AdminAppColors.errorLight;
      default:
        return AdminAppColors.textSecondaryLight;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'matching':
        return 'قيد التعيين';
      case 'accepted':
        return 'تم القبول';
      case 'onRoute':
        return 'في الطريق';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
      case 'cancelledByAdmin':
      case 'cancelled_by_admin':
      case 'cancelledByDriver':
      case 'cancelledByClient':
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _QuickActionCard(icon: icon, title: title, color: color, isDark: isDark, onTap: onTap);
  }
}

/// Quick action card with hover animation
class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminAnimations.fast,
          curve: AdminAnimations.defaultCurve,
          transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
          decoration: BoxDecoration(
            color: widget.isDark ? AdminAppColors.cardDark : AdminAppColors.cardLight,
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
            border: Border.all(
              color: _isHovered
                  ? widget.color.withOpacity(0.4)
                  : (widget.isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered ? widget.color.withOpacity(0.15) : Colors.black.withOpacity(0.03),
                blurRadius: _isHovered ? 12 : 4,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AdminSpacing.lg),
          child: Column(
            children: [
              AnimatedContainer(
                duration: AdminAnimations.fast,
                padding: const EdgeInsets.all(AdminSpacing.sm),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(_isHovered ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                ),
                child: Icon(widget.icon, color: widget.color, size: 32),
              ),
              const SizedBox(height: AdminSpacing.sm),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  color: _isHovered ? widget.color : null,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
