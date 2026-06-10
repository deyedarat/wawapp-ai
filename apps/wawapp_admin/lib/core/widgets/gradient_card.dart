import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/animations.dart';

/// A premium card widget with gradient background, glass effect, and hover animations.
/// Useful for hero stats, important alerts, and summary sections.
class GradientCard extends StatefulWidget {
  final Widget child;
  final List<Color>? gradientColors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool enableGlassEffect;

  const GradientCard({
    super.key,
    required this.child,
    this.gradientColors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.width,
    this.height,
    this.padding,
    this.onTap,
    this.enableGlassEffect = false,
  });

  /// Creates a primary green gradient card
  factory GradientCard.primary({
    Key? key,
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      key: key,
      gradientColors: const [Color(0xFF00704A), Color(0xFF00895A)],
      child: child,
      width: width,
      height: height,
      padding: padding,
      onTap: onTap,
    );
  }

  /// Creates a golden gradient card
  factory GradientCard.golden({
    Key? key,
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      key: key,
      gradientColors: const [Color(0xFFF5A623), Color(0xFFFFCC02)],
      child: child,
      width: width,
      height: height,
      padding: padding,
      onTap: onTap,
    );
  }

  /// Creates a glass-effect card (frosted glass)
  factory GradientCard.glass({
    Key? key,
    required Widget child,
    double? width,
    double? height,
    EdgeInsets? padding,
    VoidCallback? onTap,
  }) {
    return GradientCard(
      key: key,
      gradientColors: const [Color(0x30FFFFFF), Color(0x10FFFFFF)],
      enableGlassEffect: true,
      child: child,
      width: width,
      height: height,
      padding: padding,
      onTap: onTap,
    );
  }

  @override
  State<GradientCard> createState() => _GradientCardState();
}

class _GradientCardState extends State<GradientCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = widget.gradientColors ?? [AdminAppColors.primaryGreen, AdminAppColors.primaryGreen.withOpacity(0.8)];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminAnimations.fast,
          curve: AdminAnimations.defaultCurve,
          width: widget.width,
          height: widget.height,
          transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: widget.begin, end: widget.end, colors: colors),
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
            boxShadow: [
              BoxShadow(
                color: colors.first.withOpacity(_isHovered ? 0.3 : 0.15),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 4),
                spreadRadius: _isHovered ? 2 : 0,
              ),
            ],
            border: widget.enableGlassEffect
                ? Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.3), width: 1)
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminSpacing.radiusMd),
            child: Stack(
              children: [
                // Decorative circles for visual interest
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                Positioned(
                  bottom: -30,
                  left: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.03)),
                  ),
                ),
                // Content
                Padding(padding: widget.padding ?? const EdgeInsets.all(AdminSpacing.lg), child: widget.child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
