import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/animations.dart';

/// Data segment for donut chart
class DonutChartSegment {
  final String label;
  final double value;
  final Color color;

  const DonutChartSegment({required this.label, required this.value, required this.color});
}

/// Interactive donut/pie chart with animation, legend, and center label.
class AdminDonutChart extends StatefulWidget {
  final List<DonutChartSegment> segments;
  final String? title;
  final double size;
  final double strokeWidth;
  final String? centerLabel;
  final String? centerValue;
  final bool showLegend;
  final bool animated;

  const AdminDonutChart({
    super.key,
    required this.segments,
    this.title,
    this.size = 200,
    this.strokeWidth = 24,
    this.centerLabel,
    this.centerValue,
    this.showLegend = true,
    this.animated = true,
  });

  @override
  State<AdminDonutChart> createState() => _AdminDonutChartState();
}

class _AdminDonutChartState extends State<AdminDonutChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _hoveredSegment;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    if (widget.animated) {
      _animController.forward();
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AdminDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.segments != widget.segments && widget.animated) {
      _animController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AdminSpacing.md),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Donut chart
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _DonutChartPainter(
                      segments: widget.segments,
                      progress: _animation.value,
                      strokeWidth: widget.strokeWidth,
                      isDark: isDark,
                      hoveredSegment: _hoveredSegment,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.centerValue != null)
                            Text(
                              widget.centerValue!,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          if (widget.centerLabel != null)
                            Text(
                              widget.centerLabel!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Legend
            if (widget.showLegend) ...[
              const SizedBox(width: AdminSpacing.xl),
              Expanded(child: _buildLegend(context, isDark)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, bool isDark) {
    final total = widget.segments.fold<double>(0, (sum, s) => sum + s.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widget.segments.asMap().entries.map((entry) {
        final index = entry.key;
        final segment = entry.value;
        final percent = total > 0 ? (segment.value / total * 100).toStringAsFixed(1) : '0';
        final isHovered = _hoveredSegment == index;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredSegment = index),
          onExit: (_) => setState(() => _hoveredSegment = null),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xs, horizontal: AdminSpacing.sm),
            margin: const EdgeInsets.only(bottom: AdminSpacing.xxs),
            decoration: BoxDecoration(
              color: isHovered ? segment.color.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminSpacing.radiusXs),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: segment.color, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: Text(
                    segment.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isHovered ? FontWeight.w600 : FontWeight.w400,
                      color: isDark ? AdminAppColors.textPrimaryDark : AdminAppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: segment.color),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<DonutChartSegment> segments;
  final double progress;
  final double strokeWidth;
  final bool isDark;
  final int? hoveredSegment;

  _DonutChartPainter({
    required this.segments,
    required this.progress,
    required this.strokeWidth,
    required this.isDark,
    this.hoveredSegment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - strokeWidth / 2 - 4;
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    // Draw background ring
    final bgPaint = Paint()
      ..color = (isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight).withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw segments
    double startAngle = -math.pi / 2; // Start from top
    final sweepTotal = 2 * math.pi * progress;

    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final sweepAngle = (segment.value / total) * sweepTotal;
      final isHovered = hoveredSegment == i;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHovered ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      final rect = Rect.fromCircle(center: center, radius: isHovered ? radius + 2 : radius);

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;

      // Gap between segments
      startAngle += 0.02;
    }
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoveredSegment != hoveredSegment ||
        oldDelegate.segments != segments;
  }
}
