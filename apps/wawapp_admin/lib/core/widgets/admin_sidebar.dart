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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Watch stats for sidebar badges
    final driverStats = ref.watch(driverStatsProvider).valueOrNull ?? {};
    final onlineDrivers = driverStats['online'] ?? 0;

    return Container(
      width: isCollapsed ? AdminSpacing.sidebarWidthCollapsed : AdminSpacing.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? AdminAppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: isRTL ? const Offset(-3, 0) : const Offset(3, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Logo / Header ──────────────────────────────────────
          _buildHeader(context, isDark),

          // ── Navigation Items ───────────────────────────────────
          Expanded(
            child: RawScrollbar(
              thumbVisibility: false,
              thickness: 3,
              radius: const Radius.circular(4),
              thumbColor: Colors.black.withOpacity(0.12),
              fadeDuration: const Duration(milliseconds: 300),
              timeToFade: const Duration(milliseconds: 800),
              child: ListView(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  // ─ التشغيل
                  if (!isCollapsed) _buildSectionLabel(context, 'التشغيل', isDark),
                  _buildNavItem(
                    context,
                    icon: Icons.dashboard_outlined,
                    label: 'لوحة التحكم',
                    path: '/',
                    isActive: currentPath == '/',
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.local_shipping_outlined,
                    label: 'الطلبات',
                    path: '/orders',
                    isActive: currentPath.startsWith('/orders'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.directions_car_outlined,
                    label: 'السائقون',
                    path: '/drivers',
                    isActive: currentPath.startsWith('/drivers'),
                    isCollapsed: isCollapsed,
                    badgeCount: onlineDrivers,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.people_outline,
                    label: 'العملاء',
                    path: '/clients',
                    isActive: currentPath.startsWith('/clients'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.map_outlined,
                    label: 'المراقبة الحية',
                    path: '/live-ops',
                    isActive: currentPath.startsWith('/live-ops'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),

                  const SizedBox(height: 8),

                  // ─ المالية والتقارير
                  if (!isCollapsed) _buildSectionLabel(context, 'المالية والتقارير', isDark),
                  _buildNavItem(
                    context,
                    icon: Icons.bar_chart_outlined,
                    label: 'التقارير',
                    path: '/reports',
                    isActive: currentPath.startsWith('/reports'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'المحافظ',
                    path: '/finance/wallets',
                    isActive: currentPath.startsWith('/finance/wallets'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.payments_outlined,
                    label: 'الدفعات',
                    path: '/finance/payouts',
                    isActive: currentPath.startsWith('/finance/payouts'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),

                  const SizedBox(height: 8),

                  // ─ النظام
                  if (!isCollapsed) _buildSectionLabel(context, 'النظام', isDark),
                  _buildNavItem(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'الإشعارات',
                    path: '/notifications',
                    isActive: currentPath.startsWith('/notifications'),
                    isCollapsed: isCollapsed,
                    badgeCount: unreadCount,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    label: 'الإعدادات',
                    path: '/settings',
                    isActive: currentPath.startsWith('/settings'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.history_outlined,
                    label: 'سجل العمليات',
                    path: '/audit-log',
                    isActive: currentPath.startsWith('/audit-log'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.place_outlined,
                    label: 'الأماكن المشتركة',
                    path: '/shared-places',
                    isActive: currentPath.startsWith('/shared-places'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                  _buildNavItem(
                    context,
                    icon: Icons.shield_outlined,
                    label: 'إدارة المسؤولين',
                    path: '/admin-users',
                    isActive: currentPath.startsWith('/admin-users'),
                    isCollapsed: isCollapsed,
                    isDark: isDark,
                    isRTL: isRTL,
                  ),
                ],
              ),
            ),
          ),

          // ── User Profile Card ──────────────────────────────────
          if (!isCollapsed) _buildUserCard(context, authService, isDark),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Header
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      height: AdminSpacing.appBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: isDark ? AdminAppColors.borderDark.withOpacity(0.5) : const Color(0xFFF0F0F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AdminAppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: AdminAppColors.primaryGreen, size: 20),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'WawApp',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AdminAppColors.textPrimaryDark : const Color(0xFF1A1D23),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
          IconButton(
            icon: Icon(isCollapsed ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 20),
            onPressed: onToggle,
            color: isDark ? AdminAppColors.textSecondaryDark : const Color(0xFF9CA3AF),
            splashRadius: 18,
            tooltip: isCollapsed ? 'توسيع' : 'طي',
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Section Label
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(BuildContext context, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Nav Item (Active Indicator Bar approach)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String path,
    required bool isActive,
    required bool isCollapsed,
    required bool isDark,
    required bool isRTL,
    int badgeCount = 0,
  }) {
    // Colors
    final activeTextColor = const Color(0xFF0F8A5F);
    final activeBgColor = isDark ? const Color(0xFF0F8A5F).withOpacity(0.12) : const Color(0xFFEAF7F1);
    final activeBarColor = const Color(0xFF12A06A);
    final defaultTextColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF2B2F38);
    final defaultIconColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hoverColor = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF6FBF8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => context.go(path),
          borderRadius: BorderRadius.circular(12),
          hoverColor: isActive ? Colors.transparent : hoverColor,
          splashColor: AdminAppColors.primaryGreen.withOpacity(0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 44,
            decoration: BoxDecoration(
              color: isActive ? activeBgColor : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Active indicator bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 4 : 0,
                  height: 24,
                  margin: EdgeInsets.only(right: isRTL ? 0 : 0, left: isRTL ? 0 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? activeBarColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                SizedBox(width: isActive ? 10 : 14),

                // Icon
                Icon(icon, color: isActive ? activeTextColor : defaultIconColor, size: 20),

                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  // Label
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? activeTextColor : defaultTextColor,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Badge
                  if (badgeCount > 0) _buildBadge(badgeCount, isActive),
                ],

                if (isCollapsed && badgeCount > 0) Positioned(child: _buildBadge(badgeCount, isActive)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Badge (smaller, softer)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBadge(int count, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF12A06A) : const Color(0xFFDC6B6B),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700, height: 1.3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // User Profile Card (redesigned)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildUserCard(BuildContext context, dynamic authService, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AdminAppColors.borderDark.withOpacity(0.4) : const Color(0xFFEEEFF2)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF12A06A), Color(0xFF0F8A5F)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'م',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المسؤول',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AdminAppColors.textPrimaryDark : const Color(0xFF1A1D23),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'admin@wawapp.mr',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF9CA3AF),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          // Logout button
          _LogoutButton(
            isDark: isDark,
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('تسجيل الخروج'),
                  content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل الخروج')),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await authService.signOut();
                if (context.mounted) context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Logout button with hover effect
// ═══════════════════════════════════════════════════════════════════
class _LogoutButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _LogoutButton({required this.isDark, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: 'تسجيل الخروج',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _isHovered
                  ? (widget.isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFEEEFF2))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.logout_rounded,
              size: 17,
              color: _isHovered
                  ? const Color(0xFFDC6B6B)
                  : (widget.isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Thin scrollbar is handled via CSS in index.html + RawScrollbar
// ═══════════════════════════════════════════════════════════════════
