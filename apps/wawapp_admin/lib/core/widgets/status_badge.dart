import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Enhanced status badge with dot indicator and improved dark mode support.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool showDot;
  final bool pulseDot;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.showDot = false,
    this.pulseDot = false,
  });

  factory StatusBadge.online(String label) {
    return StatusBadge(label: label, color: AdminAppColors.onlineGreen, showDot: true, pulseDot: true);
  }

  factory StatusBadge.offline(String label) {
    return StatusBadge(label: label, color: AdminAppColors.offlineGrey, showDot: true);
  }

  factory StatusBadge.active(String label) {
    return StatusBadge(label: label, color: AdminAppColors.activeBlue, icon: Icons.access_time_rounded);
  }

  factory StatusBadge.pending(String label) {
    return StatusBadge(label: label, color: AdminAppColors.pendingYellow, icon: Icons.hourglass_empty_rounded);
  }

  factory StatusBadge.success(String label) {
    return StatusBadge(label: label, color: AdminAppColors.successLight, icon: Icons.check_circle_rounded);
  }

  factory StatusBadge.error(String label) {
    return StatusBadge(label: label, color: AdminAppColors.errorLight, icon: Icons.cancel_rounded);
  }

  factory StatusBadge.warning(String label) {
    return StatusBadge(label: label, color: AdminAppColors.warningLight, icon: Icons.warning_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AdminAppColors.textSecondaryLight;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.sm, vertical: AdminSpacing.xxs + 1),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
        border: Border.all(color: badgeColor.withOpacity(isDark ? 0.3 : 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            _StatusDot(color: badgeColor, pulse: pulseDot),
            const SizedBox(width: AdminSpacing.xxs + 2),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: badgeColor),
            const SizedBox(width: AdminSpacing.xxs),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: badgeColor, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Animated dot for online/active statuses
class _StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;

  const _StatusDot({required this.color, this.pulse = false});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.5),
                blurRadius: 4,
                spreadRadius: _animation.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
