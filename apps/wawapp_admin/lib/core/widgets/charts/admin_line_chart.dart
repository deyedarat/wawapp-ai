import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/animations.dart';

/// Data point for line chart
class LineChartPoint {
  final String label;
  final double value;

  const LineChartPoint({required this.label, required this.value});
}

/// Data series for the line chart
class LineChartSeries {
  final String name;
  final List<LineChartPoint> points;
  final Color color;

  const LineChartSeries({required this.name, required this.points, required this.color});
}

/// Interactive line chart with gradient fill, animation, and multi-series support.
class AdminLineChart extends StatefulWidget {
  final List<LineChartSeries> series;
  final String? title;
  final double height;
  final bool showDots;
  final bool showGrid;
  final bool animated;
  final bool showLegend;

  const AdminLineChart({
    super.key,
    required this.series,
    this.title,
    this.height = 250,
    this.showDots = true,
    this.showGrid = true,
    this.animated = true,
    this.showLegend = true,
  });

  @override
  State<AdminLineChart> createState() => _AdminLineChartState();
}

class _AdminLineChartState extends State<AdminLineChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  Offset? _hoverPosition;
  int? _hoveredPointIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    if (widget.animated) {
      _animController.forward();
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AdminLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.series != widget.series && widget.animated) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.showLegend && widget.series.length > 1) _buildLegend(context, isDark),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
        ],
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return MouseRegion(
                    onHover: (event) {
                      setState(() => _hoverPosition = event.localPosition);
                    },
                    onExit: (_) {
                      setState(() {
                        _hoverPosition = null;
                        _hoveredPointIndex = null;
                      });
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, widget.height),
                      painter: _LineChartPainter(
                        series: widget.series,
                        progress: _animation.value,
                        isDark: isDark,
                        showDots: widget.showDots,
                        showGrid: widget.showGrid,
                        hoverPosition: _hoverPosition,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // X-axis labels
        if (widget.series.isNotEmpty) ...[const SizedBox(height: 8), _buildXAxisLabels(context, isDark)],
      ],
    );
  }

  Widget _buildLegend(BuildContext context, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widget.series.map((s) {
        return Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 3,
                decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Text(
                s.name,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildXAxisLabels(BuildContext context, bool isDark) {
    final points = widget.series.first.points;
    final maxLabels = 7;
    final step = (points.length / maxLabels).ceil().clamp(1, points.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate((points.length / step).ceil().clamp(0, maxLabels), (i) {
        final index = i * step;
        if (index >= points.length) return const SizedBox.shrink();
        return Text(
          points[index].label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
          ),
        );
      }),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<LineChartSeries> series;
  final double progress;
  final bool isDark;
  final bool showDots;
  final bool showGrid;
  final Offset? hoverPosition;

  _LineChartPainter({
    required this.series,
    required this.progress,
    required this.isDark,
    required this.showDots,
    required this.showGrid,
    this.hoverPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final padding = const EdgeInsets.only(left: 40, right: 16, top: 16, bottom: 8);
    final chartRect = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.left - padding.right,
      size.height - padding.top - padding.bottom,
    );

    // Calculate max value across all series
    double maxValue = 0;
    for (final s in series) {
      for (final p in s.points) {
        if (p.value > maxValue) maxValue = p.value;
      }
    }
    if (maxValue == 0) maxValue = 1;

    // Draw grid
    if (showGrid) {
      _drawGrid(canvas, chartRect, maxValue);
    }

    // Draw each series
    for (final s in series) {
      _drawSeries(canvas, chartRect, s, maxValue);
    }

    // Draw hover indicator
    if (hoverPosition != null) {
      _drawHoverIndicator(canvas, chartRect);
    }
  }

  void _drawGrid(Canvas canvas, Rect chartRect, double maxValue) {
    final gridPaint = Paint()
      ..color = (isDark ? AdminAppColors.borderDark : AdminAppColors.borderLight).withOpacity(0.5)
      ..strokeWidth = 0.5;

    final textStyle = TextStyle(
      fontSize: 10,
      color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
    );

    // Horizontal grid lines (4 lines)
    for (int i = 0; i <= 4; i++) {
      final y = chartRect.top + (chartRect.height * i / 4);
      canvas.drawLine(Offset(chartRect.left, y), Offset(chartRect.right, y), gridPaint);

      // Y-axis labels
      final value = maxValue * (4 - i) / 4;
      final textSpan = TextSpan(text: value.toStringAsFixed(0), style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(chartRect.left - tp.width - 8, y - tp.height / 2));
    }
  }

  void _drawSeries(Canvas canvas, Rect chartRect, LineChartSeries s, double maxValue) {
    if (s.points.isEmpty) return;

    final points = <Offset>[];
    final stepX = chartRect.width / (s.points.length - 1).clamp(1, double.infinity);

    for (int i = 0; i < s.points.length; i++) {
      final x = chartRect.left + stepX * i;
      final normalizedValue = (s.points[i].value / maxValue).clamp(0.0, 1.0);
      final y = chartRect.bottom - (normalizedValue * chartRect.height * progress);
      points.add(Offset(x, y));
    }

    // Draw gradient fill
    if (points.length >= 2) {
      final fillPath = Path()..moveTo(points.first.dx, chartRect.bottom);
      for (final p in points) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(points.last.dx, chartRect.bottom);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [s.color.withOpacity(0.2), s.color.withOpacity(0.02)],
        ).createShader(chartRect);
      canvas.drawPath(fillPath, fillPaint);

      // Draw line
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        linePath.lineTo(points[i].dx, points[i].dy);
      }

      final linePaint = Paint()
        ..color = s.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(linePath, linePaint);
    }

    // Draw dots
    if (showDots) {
      for (final p in points) {
        canvas.drawCircle(p, 4, Paint()..color = s.color);
        canvas.drawCircle(p, 2.5, Paint()..color = Colors.white);
      }
    }
  }

  void _drawHoverIndicator(Canvas canvas, Rect chartRect) {
    if (hoverPosition == null) return;
    if (hoverPosition!.dx < chartRect.left || hoverPosition!.dx > chartRect.right) return;

    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..strokeWidth = 1;

    canvas.drawLine(Offset(hoverPosition!.dx, chartRect.top), Offset(hoverPosition!.dx, chartRect.bottom), linePaint);
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hoverPosition != hoverPosition ||
        oldDelegate.series != series;
  }
}
