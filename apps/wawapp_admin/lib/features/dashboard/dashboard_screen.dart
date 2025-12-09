import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/stat_card.dart';
import '../../providers/admin_data_providers.dart';

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
              ElevatedButton(
                onPressed: () => ref.refresh(dashboardStatsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (stats) {
          final orderStats = stats['orders'] as Map<String, int>? ?? {};
          final driverStats = stats['drivers'] as Map<String, int>? ?? {};
          final clientStats = stats['clients'] as Map<String, int>? ?? {};

          final totalDrivers = driverStats['total'] ?? 0;
          final onlineDrivers = driverStats['online'] ?? 0;
          final activeOrders = orderStats['assigning'] ?? 0 + 
                             orderStats['accepted'] ?? 0 + 
                             orderStats['on_route'] ?? 0;
          final completedToday = orderStats['completed'] ?? 0;
          final cancelledToday = orderStats['cancelled'] ?? 0;

          final onlinePercent = totalDrivers > 0 
              ? (onlineDrivers / totalDrivers * 100).toInt() 
              : 0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary stats grid
              GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: AdminSpacing.md,
                mainAxisSpacing: AdminSpacing.md,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                children: [
                  StatCard(
                    title: 'السائقون النشطون',
                    value: '$onlineDrivers',
                    icon: Icons.drive_eta,
                    color: AdminAppColors.onlineGreen,
                    subtitle: '$onlinePercent٪ متصلون',
                    onTap: () => context.go('/drivers'),
                  ),
                  StatCard(
                    title: 'الطلبات الجارية',
                    value: '$activeOrders',
                    icon: Icons.local_shipping,
                    color: AdminAppColors.activeBlue,
                    subtitle: 'قيد التوصيل',
                    onTap: () => context.go('/orders'),
                  ),
                  StatCard(
                    title: 'طلبات اليوم',
                    value: '$completedToday',
                    icon: Icons.check_circle,
                    color: AdminAppColors.successLight,
                    subtitle: 'مكتملة',
                  ),
                  StatCard(
                    title: 'طلبات ملغاة',
                    value: '$cancelledToday',
                    icon: Icons.cancel,
                    color: AdminAppColors.errorLight,
                    subtitle: 'اليوم',
                  ),
                ],
              ),

          SizedBox(height: AdminSpacing.xl),

          // Recent activity section
          Text(
            'النشاط الأخير',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AdminSpacing.md),

          Card(
            child: Padding(
              padding: EdgeInsets.all(AdminSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildActivityItem(
                    context,
                    icon: Icons.add_circle,
                    color: AdminAppColors.successLight,
                    title: 'طلب جديد تم إنشاؤه',
                    subtitle: 'الطلب #12345 من نواكشوط إلى نواذيبو',
                    time: 'منذ 5 دقائق',
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildActivityItem(
                    context,
                    icon: Icons.drive_eta,
                    color: AdminAppColors.onlineGreen,
                    title: 'سائق جديد متصل',
                    subtitle: 'محمد ولد أحمد بدأ نوبته',
                    time: 'منذ 15 دقيقة',
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildActivityItem(
                    context,
                    icon: Icons.check_circle,
                    color: AdminAppColors.primaryGreen,
                    title: 'طلب مكتمل',
                    subtitle: 'الطلب #12344 تم تسليمه بنجاح',
                    time: 'منذ 30 دقيقة',
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildActivityItem(
                    context,
                    icon: Icons.cancel,
                    color: AdminAppColors.errorLight,
                    title: 'طلب ملغى',
                    subtitle: 'الطلب #12343 ألغاه العميل',
                    time: 'منذ ساعة',
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AdminSpacing.xl),

          // Quick actions
          Row(
            children: [
              Expanded(
                child: Text(
                  'إجراءات سريعة',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          SizedBox(height: AdminSpacing.md),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.add,
                  title: 'إضافة سائق',
                  color: AdminAppColors.primaryGreen,
                  onTap: () {
                    // TODO: Navigate to add driver
                  },
                ),
              ),
              SizedBox(width: AdminSpacing.md),
              Expanded(
                child: _buildQuickActionCard(
                  context,
                  icon: Icons.person_add,
                  title: 'إضافة عميل',
                  color: AdminAppColors.activeBlue,
                  onTap: () {
                    // TODO: Navigate to add client
                  },
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
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              SizedBox(height: AdminSpacing.xxs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Text(
          time,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AdminAppColors.textSecondaryLight,
          ),
        ),
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
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
