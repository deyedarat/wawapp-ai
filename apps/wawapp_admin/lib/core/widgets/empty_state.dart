import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/animations.dart';

/// Professional empty state widget with animation and optional action button.
/// Use this when lists, tables, or sections have no data to display.
class AdminEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final double iconSize;
  final bool compact;

  const AdminEmptyState({
    super.key,
    this.icon = Icons.inbox_outlined,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.iconSize = 72,
    this.compact = false,
  });

  /// No orders empty state
  factory AdminEmptyState.noOrders({VoidCallback? onAction}) {
    return AdminEmptyState(
      icon: Icons.local_shipping_outlined,
      title: 'لا توجد طلبات',
      description: 'لم يتم إنشاء أي طلبات بعد',
      actionLabel: 'إنشاء طلب جديد',
      actionIcon: Icons.add,
      onAction: onAction,
    );
  }

  /// No drivers empty state
  factory AdminEmptyState.noDrivers({VoidCallback? onAction}) {
    return AdminEmptyState(
      icon: Icons.drive_eta_outlined,
      title: 'لا يوجد سائقون',
      description: 'لم يتم تسجيل أي سائق بعد',
      actionLabel: onAction != null ? 'إضافة سائق' : null,
      actionIcon: Icons.person_add_outlined,
      onAction: onAction,
    );
  }

  /// No results (search) empty state
  factory AdminEmptyState.noResults({String? searchQuery}) {
    return AdminEmptyState(
      icon: Icons.search_off_outlined,
      title: 'لا توجد نتائج',
      description: searchQuery != null ? 'لم يتم العثور على نتائج لـ "$searchQuery"' : 'جرب تغيير معايير البحث',
    );
  }

  /// Error state
  factory AdminEmptyState.error({String? message, VoidCallback? onRetry}) {
    return AdminEmptyState(
      icon: Icons.error_outline,
      title: 'حدث خطأ',
      description: message ?? 'تعذّر تحميل البيانات. يرجى المحاولة مرة أخرى.',
      actionLabel: 'إعادة المحاولة',
      actionIcon: Icons.refresh,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SlideInAnimation(
      begin: const Offset(0, 0.05),
      duration: AdminAnimations.slow,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AdminSpacing.lg : AdminSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon with circle background
            Container(
              padding: EdgeInsets.all(compact ? AdminSpacing.md : AdminSpacing.xl),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? AdminAppColors.primaryGreen : AdminAppColors.primaryGreen).withOpacity(0.08),
                    (isDark ? AdminAppColors.primaryGreen : AdminAppColors.primaryGreen).withOpacity(0.03),
                  ],
                ),
              ),
              child: Icon(
                icon,
                size: compact ? iconSize * 0.6 : iconSize,
                color: isDark
                    ? AdminAppColors.textSecondaryDark.withOpacity(0.6)
                    : AdminAppColors.textSecondaryLight.withOpacity(0.5),
              ),
            ),
            SizedBox(height: compact ? AdminSpacing.md : AdminSpacing.lg),
            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDark ? AdminAppColors.textPrimaryDark : AdminAppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            // Description
            if (description != null) ...[
              SizedBox(height: compact ? AdminSpacing.xs : AdminSpacing.sm),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // Action button
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? AdminSpacing.md : AdminSpacing.xl),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: actionIcon != null ? Icon(actionIcon, size: 18) : const SizedBox.shrink(),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminAppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.lg, vertical: AdminSpacing.sm),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminSpacing.radiusSm)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
