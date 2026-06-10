import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';

/// Breadcrumb item data
class BreadcrumbItem {
  final String label;
  final String? path;
  final IconData? icon;

  const BreadcrumbItem({required this.label, this.path, this.icon});
}

/// Breadcrumb navigation widget for the admin panel.
/// Provides hierarchical navigation with smooth animations.
class AdminBreadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const AdminBreadcrumb({super.key, required this.items});

  /// Auto-generate breadcrumb from current route path
  factory AdminBreadcrumb.fromRoute(BuildContext context) {
    final currentPath = GoRouterState.of(context).uri.path;
    final segments = currentPath.split('/').where((s) => s.isNotEmpty).toList();

    final items = <BreadcrumbItem>[const BreadcrumbItem(label: 'الرئيسية', path: '/', icon: Icons.home_outlined)];

    String buildPath = '';
    for (int i = 0; i < segments.length; i++) {
      buildPath += '/${segments[i]}';
      final isLast = i == segments.length - 1;
      items.add(BreadcrumbItem(label: _getArabicLabel(segments[i]), path: isLast ? null : buildPath));
    }

    return AdminBreadcrumb(items: items);
  }

  static String _getArabicLabel(String segment) {
    const labels = {
      'orders': 'الطلبات',
      'drivers': 'السائقون',
      'clients': 'العملاء',
      'live-ops': 'المراقبة الحية',
      'reports': 'التقارير',
      'finance': 'المالية',
      'wallets': 'المحافظ',
      'payouts': 'الدفعات',
      'notifications': 'الإشعارات',
      'settings': 'الإعدادات',
      'pricing': 'التسعير',
      'zones': 'المناطق',
      'hours': 'ساعات العمل',
      'security': 'الأمان',
      'audit-log': 'سجل العمليات',
      'shared-places': 'الأماكن المشتركة',
      'admin-users': 'إدارة المسؤولين',
      'notification-analytics': 'تحليلات الإشعارات',
    };
    return labels[segment] ?? segment;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md, vertical: AdminSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AdminAppColors.surfaceDark.withOpacity(0.5) : AdminAppColors.backgroundLight,
        borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        border: Border.all(color: isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight, width: 0.5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: _buildBreadcrumbItems(context, isDark)),
    );
  }

  List<Widget> _buildBreadcrumbItems(BuildContext context, bool isDark) {
    final widgets = <Widget>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      // Breadcrumb item
      widgets.add(_BreadcrumbItemWidget(item: item, isActive: isLast, isDark: isDark));

      // Separator
      if (!isLast) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.xs),
            child: Icon(
              Icons.chevron_left, // RTL: left arrow as separator
              size: 16,
              color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
            ),
          ),
        );
      }
    }

    return widgets;
  }
}

class _BreadcrumbItemWidget extends StatefulWidget {
  final BreadcrumbItem item;
  final bool isActive;
  final bool isDark;

  const _BreadcrumbItemWidget({required this.item, required this.isActive, required this.isDark});

  @override
  State<_BreadcrumbItemWidget> createState() => _BreadcrumbItemWidgetState();
}

class _BreadcrumbItemWidgetState extends State<_BreadcrumbItemWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final canNavigate = widget.item.path != null && !widget.isActive;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: canNavigate ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: canNavigate ? () => context.go(widget.item.path!) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.xs, vertical: AdminSpacing.xxs),
          decoration: BoxDecoration(
            color: _isHovered && canNavigate ? AdminAppColors.primaryGreen.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(AdminSpacing.radiusXs),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.item.icon != null) ...[
                Icon(
                  widget.item.icon,
                  size: 16,
                  color: widget.isActive
                      ? AdminAppColors.primaryGreen
                      : (_isHovered
                            ? AdminAppColors.primaryGreen
                            : (widget.isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight)),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                widget.item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w400,
                  color: widget.isActive
                      ? AdminAppColors.primaryGreen
                      : (_isHovered
                            ? AdminAppColors.primaryGreen
                            : (widget.isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight)),
                  decoration: _isHovered && canNavigate ? TextDecoration.underline : null,
                  decorationColor: AdminAppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
