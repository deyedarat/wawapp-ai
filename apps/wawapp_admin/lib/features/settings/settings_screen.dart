import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'الإعدادات',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── General Settings ──────────────────────────────────
            Text('إعدادات عامة',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    _buildSettingItem(
                      context,
                      icon: Icons.language,
                      title: 'اللغة',
                      subtitle: 'العربية',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showComingSoon(context),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.dark_mode,
                      title: 'السمة',
                      subtitle: 'فاتحة',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showComingSoon(context),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.notifications,
                      title: 'الإشعارات',
                      subtitle: 'مفعلة',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showComingSoon(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AdminSpacing.xl),

            // ── App Settings ──────────────────────────────────────
            Text('إعدادات التطبيق',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    _buildSettingItem(
                      context,
                      icon: Icons.monetization_on,
                      title: 'أسعار التوصيل',
                      subtitle: 'إدارة أسعار الخدمات',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/pricing'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.map,
                      title: 'المناطق المخدومة',
                      subtitle: 'إدارة مناطق التغطية',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/zones'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.timer,
                      title: 'أوقات العمل',
                      subtitle: 'تحديد أوقات الخدمة',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/hours'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AdminSpacing.xl),

            // ── System Settings ───────────────────────────────────
            Text('إعدادات النظام',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    _buildSettingItem(
                      context,
                      icon: Icons.backup,
                      title: 'النسخ الاحتياطي',
                      subtitle: 'آخر نسخة: 2024-12-09',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showComingSoon(context),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.security,
                      title: 'الأمان والخصوصية',
                      subtitle: 'إعدادات الحماية',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/security'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.info,
                      title: 'عن التطبيق',
                      subtitle: 'الإصدار 1.0.0',
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('هذه الميزة قيد التطوير - Coming Soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'WawApp Admin',
      applicationVersion: '1.0.0',
      applicationIcon: const FlutterLogo(size: 48),
      children: const [
        Text('لوحة التحكم الإدارية لتطبيق واو للتوصيل'),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xs),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AdminSpacing.sm),
              decoration: BoxDecoration(
                color: AdminAppColors.primaryGreen.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Icon(icon,
                  color: AdminAppColors.primaryGreen, size: 24),
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AdminAppColors.textSecondaryLight),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
