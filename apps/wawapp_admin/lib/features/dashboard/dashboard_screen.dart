import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'لوحة التحكم',
      child: Column(
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
                value: '24',
                icon: Icons.drive_eta,
                color: AdminAppColors.onlineGreen,
                subtitle: '٪85 متصلون',
                onTap: () => context.go('/drivers'),
              ),
              StatCard(
                title: 'الطلبات الجارية',
                value: '12',
                icon: Icons.local_shipping,
                color: AdminAppColors.activeBlue,
                subtitle: 'قيد التوصيل',
                onTap: () => context.go('/orders'),
              ),
              StatCard(
                title: 'طلبات اليوم',
                value: '47',
                icon: Icons.check_circle,
                color: AdminAppColors.successLight,
                subtitle: 'مكتملة',
              ),
              StatCard(
                title: 'طلبات ملغاة',
                value: '5',
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
