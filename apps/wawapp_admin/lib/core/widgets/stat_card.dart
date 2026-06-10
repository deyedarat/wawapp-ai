import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/animations.dart';

/// Enhanced stat card with gradient accents, hover effects, and smooth animations.
class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? trend; // e.g. "+12%" or "-5%"
  final bool isPositiveTrend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
    this.trend,
    this.isPositiveTrend = true,
  });

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AdminAnimations.fast);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(parent: _controller, curve: AdminAnimations.defaultCurve));
    _elevationAnimation = Tween<double>(
      begin: 2.0,
      end: 8.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AdminAnimations.defaultCurve));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoverChanged(bool isHovered) {
    setState(() => _isHovered = isHovered);
    if (isHovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? AdminAppColors.primaryGreen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => _onHoverChanged(true),
      onExit: (_) => _onHoverChanged(false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withOpacity(_isHovered ? 0.15 : 0.05),
                    blurRadius: _elevationAnimation.value * 2,
                    offset: Offset(0, _elevationAnimation.value / 2),
                    spreadRadius: _isHovered ? 1 : 0,
                  ),
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.black).withOpacity(0.05),
                    blurRadius: _elevationAnimation.value,
                    offset: Offset(0, _elevationAnimation.value / 4),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Card(
          elevation: 0, // We handle shadows manually
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
            side: BorderSide(
              color: _isHovered
                  ? cardColor.withOpacity(0.3)
                  : (isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight),
              width: _isHovered ? 1.5 : 1.0,
            ),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
            hoverColor: cardColor.withOpacity(0.03),
            splashColor: cardColor.withOpacity(0.1),
            child: Container(
              padding: const EdgeInsets.all(AdminSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
                // Subtle gradient accent at top
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [cardColor.withOpacity(_isHovered ? 0.06 : 0.02), Colors.transparent],
                  stops: const [0.0, 0.6],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icon container with gradient background
                      Container(
                        padding: const EdgeInsets.all(AdminSpacing.sm),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [cardColor.withOpacity(0.15), cardColor.withOpacity(0.08)],
                          ),
                          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                        ),
                        child: Icon(widget.icon, color: cardColor, size: 24),
                      ),
                      // Trend indicator
                      if (widget.trend != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.xs, vertical: AdminSpacing.xxs),
                          decoration: BoxDecoration(
                            color: widget.isPositiveTrend
                                ? AdminAppColors.successLight.withOpacity(0.1)
                                : AdminAppColors.errorLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusFull),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isPositiveTrend ? Icons.trending_up : Icons.trending_down,
                                size: 14,
                                color: widget.isPositiveTrend ? AdminAppColors.successLight : AdminAppColors.errorLight,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                widget.trend!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isPositiveTrend
                                      ? AdminAppColors.successLight
                                      : AdminAppColors.errorLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (widget.onTap != null && widget.trend == null)
                        AnimatedRotation(
                          turns: _isHovered ? 0.0 : 0.0,
                          duration: AdminAnimations.fast,
                          child: Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: _isHovered ? cardColor : AdminAppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AdminSpacing.md),
                  // Title
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AdminSpacing.xs),
                  // Value
                  Text(
                    widget.value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AdminAppColors.textPrimaryDark : cardColor,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: AdminSpacing.xs),
                    Text(
                      widget.subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
