import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Skeleton loading placeholder for content that is still loading.
/// Creates a shimmer animation effect for placeholder UI.
class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final bool isCircle;

  const SkeletonLoader({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8.0,
    this.isCircle = false,
  });

  /// Create a text-line shaped skeleton
  factory SkeletonLoader.text({double width = 200, double height = 14}) {
    return SkeletonLoader(width: width, height: height, borderRadius: 4);
  }

  /// Create a circle avatar skeleton
  factory SkeletonLoader.circle({double size = 40}) {
    return SkeletonLoader(width: size, height: size, isCircle: true);
  }

  /// Create a card-shaped skeleton
  factory SkeletonLoader.card({double? width, double height = 120}) {
    return SkeletonLoader(width: width ?? double.infinity, height: height, borderRadius: 12);
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shimmerColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: widget.isCircle ? null : BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [baseColor, shimmerColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton layouts for common patterns
class SkeletonLayouts {
  SkeletonLayouts._();

  /// Stat cards skeleton (4 cards in a row)
  static Widget statCards() {
    return Row(
      children: List.generate(4, (i) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 16 : 0),
            child: SkeletonLoader.card(height: 130),
          ),
        );
      }),
    );
  }

  /// Table skeleton with header and rows
  static Widget table({int rows = 5}) {
    return Column(
      children: [
        // Header
        SkeletonLoader(height: 48, borderRadius: 8),
        const SizedBox(height: 8),
        // Rows
        ...List.generate(rows, (i) {
          return Padding(padding: const EdgeInsets.only(bottom: 4), child: SkeletonLoader(height: 52, borderRadius: 4));
        }),
      ],
    );
  }

  /// List item skeleton
  static Widget listItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SkeletonLoader.circle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader.text(width: 150),
                const SizedBox(height: 8),
                SkeletonLoader.text(width: 100, height: 12),
              ],
            ),
          ),
          SkeletonLoader.text(width: 60),
        ],
      ),
    );
  }

  /// Activity list skeleton
  static Widget activityList({int items = 5}) {
    return Column(
      children: List.generate(items, (i) {
        return Column(children: [listItem(), if (i < items - 1) const Divider()]);
      }),
    );
  }
}
