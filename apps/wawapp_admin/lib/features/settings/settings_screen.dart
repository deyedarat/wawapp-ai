import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هذه الميزة قيد التطوير - Coming Soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'الإعدادات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // General settings
          Text(
            'إعدادات عامة',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AdminSpacing.md),

          Card(
            child: Padding(
              padding: EdgeInsets.all(AdminSpacing.lg),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.language,
                    title: 'اللغة',
                    subtitle: 'العربية',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.dark_mode,
                    title: 'السمة',
                    subtitle: 'فاتحة',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.notifications,
                    title: 'الإشعارات',
                    subtitle: 'مفعلة',
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AdminSpacing.xl),

          // App settings
          Text(
            'إعدادات التطبيق',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AdminSpacing.md),

          Card(
            child: Padding(
              padding: EdgeInsets.all(AdminSpacing.lg),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.monetization_on,
                    title: 'أسعار التوصيل',
                    subtitle: 'إدارة أسعار الخدمات',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.map,
                    title: 'المناطق المخدومة',
                    subtitle: 'إدارة مناطق التغطية',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.timer,
                    title: 'أوقات العمل',
                    subtitle: 'تحديد أوقات الخدمة',
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AdminSpacing.xl),

          // System settings
          Text(
            'إعدادات النظام',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: AdminSpacing.md),

          Card(
            child: Padding(
              padding: EdgeInsets.all(AdminSpacing.lg),
              child: Column(
                children: [
                  _buildSettingItem(
                    context,
                    icon: Icons.backup,
                    title: 'النسخ الاحتياطي',
                    subtitle: 'آخر نسخة: 2024-12-09',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.security,
                    title: 'الأمان والخصوصية',
                    subtitle: 'إعدادات الحماية',
                    onTap: () => _showComingSoon(context),
                  ),
                  Divider(height: AdminSpacing.lg),
                  _buildSettingItem(
                    context,
                    icon: Icons.info,
                    title: 'عن التطبيق',
                    subtitle: 'الإصدار 1.0.0',
                    onTap: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AdminSpacing.xs),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(AdminSpacing.sm),
              decoration: BoxDecoration(
                color: AdminAppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Icon(
                icon,
                color: AdminAppColors.primaryGreen,
                size: 24,
              ),
            ),
            SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: AdminSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdminAppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AdminAppColors.textSecondaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
