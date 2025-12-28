import 'package:flutter/material.dart';
import 'colors.dart';

/// Reusable UI components for the driver app

/// Primary action button with consistent styling
class DriverActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;
  final Color? backgroundColor;

  const DriverActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
    this.isLoading = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: DriverAppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          elevation: DriverAppElevation.low,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : icon != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRTL) ...[
                        Icon(icon, size: 20),
                        SizedBox(width: DriverAppSpacing.xs),
                      ],
                      Text(label),
                      if (isRTL) ...[
                        SizedBox(width: DriverAppSpacing.xs),
                        Icon(icon, size: 20),
                      ],
                    ],
                  )
                : Text(label),
      ),
    );
  }
}

/// Secondary button with outline style
class DriverSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isFullWidth;

  const DriverSecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: DriverAppSpacing.buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.primary,
          padding: EdgeInsets.symmetric(
            horizontal: DriverAppSpacing.lg,
            vertical: DriverAppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
          ),
          side: BorderSide(color: theme.colorScheme.primary),
        ),
        child: icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isRTL) ...[
                    Icon(icon, size: 20),
                    SizedBox(width: DriverAppSpacing.xs),
                  ],
                  Text(label),
                  if (isRTL) ...[
                    SizedBox(width: DriverAppSpacing.xs),
                    Icon(icon, size: 20),
                  ],
                ],
              )
            : Text(label),
      ),
    );
  }
}

/// Consistent card widget with elevation
class DriverCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const DriverCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: DriverAppElevation.low,
      color: color ?? theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusMd),
        child: Padding(
          padding: padding ?? EdgeInsets.all(DriverAppSpacing.md),
          child: child,
        ),
      ),
    );
  }
}

/// Status badge for online/offline/busy states
class DriverStatusBadge extends StatelessWidget {
  final String status;
  final Color? color;

  const DriverStatusBadge({
    super.key,
    required this.status,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    Color badgeColor;
    IconData badgeIcon;

    switch (status.toLowerCase()) {
      case 'online':
      case 'متصل':
        badgeColor = DriverAppColors.onlineGreen;
        badgeIcon = Icons.check_circle;
        break;
      case 'offline':
      case 'غير متصل':
        badgeColor = DriverAppColors.offlineGrey;
        badgeIcon = Icons.cancel;
        break;
      case 'busy':
      case 'مشغول':
        badgeColor = DriverAppColors.busyOrange;
        badgeIcon = Icons.warning;
        break;
      default:
        badgeColor = color ?? DriverAppColors.offlineGrey;
        badgeIcon = Icons.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DriverAppSpacing.sm,
        vertical: DriverAppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DriverAppSpacing.radiusFull),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Icon(badgeIcon, size: 16, color: badgeColor),
          SizedBox(width: DriverAppSpacing.xxs),
          Text(
            status,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget
class DriverEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DriverEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.disabledColor),
          SizedBox(height: DriverAppSpacing.md),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.disabledColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: DriverAppSpacing.lg),
            DriverActionButton(
              label: actionLabel!,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading indicator
class DriverLoadingIndicator extends StatelessWidget {
  final String? message;

  const DriverLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
          ),
          if (message != null) ...[
            SizedBox(height: DriverAppSpacing.md),
            Text(
              message!,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Info tile for displaying key-value pairs
class DriverInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const DriverInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: DriverAppSpacing.xs),
        child: Row(
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            SizedBox(width: DriverAppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: DriverAppSpacing.xxs),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                isRTL ? Icons.chevron_left : Icons.chevron_right,
                size: 20,
                color: theme.disabledColor,
              ),
          ],
        ),
      ),
    );
  }
}
