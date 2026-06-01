import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return AdminScaffold(
      title: 'الإعدادات',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── General Settings ──────────────────────────────────
            Text('إعدادات عامة', style: Theme.of(context).textTheme.titleLarge),
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
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => _showLanguageDialog(context),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: isDark ? Icons.dark_mode : Icons.light_mode,
                      title: 'السمة',
                      subtitle: isDark ? 'داكنة' : 'فاتحة',
                      trailing: Switch(
                        value: isDark,
                        onChanged: (_) {
                          ref.read(themeModeProvider.notifier).toggle();
                        },
                        activeColor: AdminAppColors.primaryGreen,
                      ),
                      onTap: () {
                        ref.read(themeModeProvider.notifier).toggle();
                      },
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.notifications,
                      title: 'الإشعارات',
                      subtitle: 'إدارة إشعارات النظام',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/notifications'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AdminSpacing.xl),

            // ── App Settings ──────────────────────────────────────
            Text('إعدادات التطبيق', style: Theme.of(context).textTheme.titleLarge),
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
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/pricing'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.map,
                      title: 'المناطق المخدومة',
                      subtitle: 'إدارة مناطق التغطية',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/zones'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.timer,
                      title: 'أوقات العمل',
                      subtitle: 'تحديد أوقات الخدمة',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/hours'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AdminSpacing.xl),

            // ── System Settings ───────────────────────────────────
            Text('إعدادات النظام', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    _buildSettingItem(
                      context,
                      icon: Icons.history,
                      title: 'سجل العمليات',
                      subtitle: 'عرض جميع الإجراءات الإدارية',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/audit-log'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.security,
                      title: 'الأمان والخصوصية',
                      subtitle: 'إعدادات الحماية',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
                      onTap: () => context.go('/settings/security'),
                    ),
                    const Divider(height: AdminSpacing.lg),
                    _buildSettingItem(
                      context,
                      icon: Icons.info,
                      title: 'عن التطبيق',
                      subtitle: 'الإصدار 1.0.0',
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AdminAppColors.textSecondaryLight),
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

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('اختيار اللغة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check, color: AdminAppColors.primaryGreen),
              title: const Text('العربية'),
              subtitle: const Text('اللغة الحالية'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.language, color: AdminAppColors.textSecondaryLight),
              title: const Text('Français'),
              subtitle: const Text('قريباً'),
              enabled: false,
              onTap: null,
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'WawApp Admin',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.admin_panel_settings, size: 48, color: AdminAppColors.primaryGreen),
      children: const [
        Text('لوحة التحكم الإدارية لتطبيق واو للتوصيل'),
        SizedBox(height: 8),
        Text('© 2024-2026 WawApp. جميع الحقوق محفوظة.'),
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
                borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Icon(icon, color: AdminAppColors.primaryGreen, size: 24),
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminAppColors.textSecondaryLight),
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
