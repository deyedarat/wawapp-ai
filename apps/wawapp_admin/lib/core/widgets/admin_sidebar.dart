import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

class AdminSidebar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const AdminSidebar({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final currentPath = GoRouterState.of(context).uri.path;

    return Container(
      width: isCollapsed 
          ? AdminSpacing.sidebarWidthCollapsed 
          : AdminSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: isRTL
              ? const BorderSide(color: AdminAppColors.borderLight)
              : BorderSide.none,
          left: !isRTL
              ? const BorderSide(color: AdminAppColors.borderLight)
              : BorderSide.none,
        ),
      ),
      child: Column(
        children: [
          // Logo / Header
          Container(
            height: AdminSpacing.appBarHeight,
            padding: EdgeInsets.symmetric(horizontal: AdminSpacing.md),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AdminAppColors.borderLight),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: AdminAppColors.primaryGreen,
                  size: 32,
                ),
                if (!isCollapsed) ...[
                  SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Text(
                      'لوحة الإدارة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AdminAppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
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
              padding: EdgeInsets.symmetric(vertical: AdminSpacing.sm),
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
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.people,
                  label: 'العملاء',
                  path: '/clients',
                  isActive: currentPath.startsWith('/clients'),
                  isCollapsed: isCollapsed,
                ),
                Divider(
                  height: AdminSpacing.lg,
                  indent: AdminSpacing.md,
                  endIndent: AdminSpacing.md,
                ),
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
                Divider(
                  height: AdminSpacing.lg,
                  indent: AdminSpacing.md,
                  endIndent: AdminSpacing.md,
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.settings,
                  label: 'الإعدادات',
                  path: '/settings',
                  isActive: currentPath.startsWith('/settings'),
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // User profile section
          if (!isCollapsed)
            Container(
              padding: EdgeInsets.all(AdminSpacing.md),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AdminAppColors.borderLight),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AdminAppColors.primaryGreen,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                  SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'المسؤول',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          'admin@wawapp.mr',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () {
                      // TODO: Implement logout
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
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xxs,
      ),
      child: Material(
        color: isActive
            ? AdminAppColors.primaryGreen.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AdminSpacing.md,
              vertical: AdminSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? AdminAppColors.primaryGreen
                      : AdminAppColors.textSecondaryLight,
                  size: 24,
                ),
                if (!isCollapsed) ...[
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isActive
                            ? AdminAppColors.primaryGreen
                            : AdminAppColors.textPrimaryLight,
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
