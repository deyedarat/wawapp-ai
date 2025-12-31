import 'package:flutter/material.dart';
import '../theme/colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  factory StatusBadge.online(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.onlineGreen,
      icon: Icons.check_circle,
    );
  }

  factory StatusBadge.offline(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.offlineGrey,
      icon: Icons.cancel,
    );
  }

  factory StatusBadge.active(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.activeBlue,
      icon: Icons.access_time,
    );
  }

  factory StatusBadge.pending(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.pendingYellow,
      icon: Icons.hourglass_empty,
    );
  }

  factory StatusBadge.success(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.successLight,
      icon: Icons.check_circle,
    );
  }

  factory StatusBadge.error(String label) {
    return StatusBadge(
      label: label,
      color: AdminAppColors.errorLight,
      icon: Icons.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AdminAppColors.textSecondaryLight;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AdminSpacing.sm,
        vertical: AdminSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: badgeColor,
            ),
            SizedBox(width: AdminSpacing.xxs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
