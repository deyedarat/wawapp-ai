import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/providers/admin_notifications_provider.dart';
import '../../providers/admin_auth_providers.dart';
import '../../providers/admin_data_providers.dart';
import '../theme/colors.dart';

class AdminSidebar extends ConsumerWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const AdminSidebar({super.key, required this.isCollapsed, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final currentPath = GoRouterState.of(context).uri.path;
    final authService = ref.read(adminAuthServiceProvider);
    final unreadCount = ref.watch(adminUnreadCountProvider).valueOrNull ?? 0;

    // Watch stats for sidebar badges
    final driverStats = ref.watch(driverStatsProvider).valueOrNull ?? {};
    final onlineDrivers = driverStats['online'] ?? 0;

    return Container(
      width: isCollapsed ? AdminSpacing.sidebarWidthCollapsed : AdminSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: isRTL ? const BorderSide(color: AdminAppColors.borderLight) : BorderSide.none,
          right: !isRTL ? const BorderSide(color: AdminAppColors.borderLight) : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // Logo / Header
          Container(
            height: AdminSpacing.appBarHeight,
            padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AdminAppColors.borderLight)),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: AdminAppColors.primaryGreen, size: 32),
                if (!isCollapsed) ...[
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      'لوحة الإدارة',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: AdminAppColors.primaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(isCollapsed ? Icons.menu : Icons.menu_open),
                  onPressed: onToggle,
                  color: AdminAppColors.textSecondaryLight,
                ),
              ],
            ),
          ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AdminSpacing.sm),
              children: [
                _buildNavItem(
                  context: context,
                  icon: Icons.dashboard,
                  label: 'لوحة التحكم',
                  path: '/',
                  isActive: currentPath == '/',
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.local_shipping,
                  label: 'الطلبات',
                  path: '/orders',
                  isActive: currentPath.startsWith('/orders'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.drive_eta,
                  label: 'السائقون',
                  path: '/drivers',
                  isActive: currentPath.startsWith('/drivers'),
                  isCollapsed: isCollapsed,
                  badgeCount: onlineDrivers,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.people,
                  label: 'العملاء',
                  path: '/clients',
                  isActive: currentPath.startsWith('/clients'),
                  isCollapsed: isCollapsed,
                ),
                const Divider(height: AdminSpacing.lg, indent: AdminSpacing.md, endIndent: AdminSpacing.md),
                _buildNavItem(
                  context: context,
                  icon: Icons.map,
                  label: 'المراقبة الحية',
                  path: '/live-ops',
                  isActive: currentPath.startsWith('/live-ops'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.bar_chart,
                  label: 'التقارير',
                  path: '/reports',
                  isActive: currentPath.startsWith('/reports'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.account_balance_wallet,
                  label: 'المحافظ',
                  path: '/finance/wallets',
                  isActive: currentPath.startsWith('/finance/wallets'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.payment,
                  label: 'الدفعات',
                  path: '/finance/payouts',
                  isActive: currentPath.startsWith('/finance/payouts'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.notifications_outlined,
                  label: 'الإشعارات',
                  path: '/notifications',
                  isActive: currentPath.startsWith('/notifications'),
                  isCollapsed: isCollapsed,
                  badgeCount: unreadCount,
                ),
                const Divider(height: AdminSpacing.lg, indent: AdminSpacing.md, endIndent: AdminSpacing.md),
                _buildNavItem(
                  context: context,
                  icon: Icons.settings,
                  label: 'الإعدادات',
                  path: '/settings',
                  isActive: currentPath.startsWith('/settings'),
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.history,
                  label: 'سجل العمليات',
                  path: '/audit-log',
                  isActive: currentPath.startsWith('/audit-log'),
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // User profile section
          if (!isCollapsed)
            Container(
              padding: const EdgeInsets.all(AdminSpacing.md),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AdminAppColors.borderLight)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AdminAppColors.primaryGreen,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('المسؤول', style: Theme.of(context).textTheme.titleSmall),
                        Text('admin@wawapp.mr', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('تسجيل الخروج'),
                          content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('تسجيل الخروج'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true && context.mounted) {
                        await authService.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                    color: AdminAppColors.textSecondaryLight,
                    tooltip: 'تسجيل الخروج',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String path,
    required bool isActive,
    required bool isCollapsed,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm, vertical: AdminSpacing.xxs),
      child: Material(
        color: isActive ? AdminAppColors.primaryGreen.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        child: InkWell(
          onTap: () {
            context.go(path);
          },
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md, vertical: AdminSpacing.sm),
            child: Row(
              children: [
                Badge(
                  label: Text('$badgeCount'),
                  isLabelVisible: badgeCount > 0,
                  child: Icon(
                    icon,
                    color: isActive ? AdminAppColors.primaryGreen : AdminAppColors.textSecondaryLight,
                    size: 24,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isActive ? AdminAppColors.primaryGreen : AdminAppColors.textPrimaryLight,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
