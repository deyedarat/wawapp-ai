import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/animations.dart';

/// Data point for bar chart
class BarChartData {
  final String label;
  final double value;
  final Color? color;

  const BarChartData({required this.label, required this.value, this.color});
}

/// Interactive bar chart with animation, tooltips, and dark mode support.
/// No external dependencies - pure Flutter CustomPainter.
class AdminBarChart extends StatefulWidget {
  final List<BarChartData> data;
  final String? title;
  final double height;
  final Color? barColor;
  final bool showValues;
  final bool animated;
  final String? valuePrefix;
  final String? valueSuffix;

  const AdminBarChart({
    super.key,
    required this.data,
    this.title,
    this.height = 250,
    this.barColor,
    this.showValues = true,
    this.animated = true,
    this.valuePrefix,
    this.valueSuffix,
  });

  @override
  State<AdminBarChart> createState() => _AdminBarChartState();
}

class _AdminBarChartState extends State<AdminBarChart> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: AdminAnimations.slow);
    _animation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    if (widget.animated) {
      _animController.forward();
    } else {
      _animController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AdminBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data && widget.animated) {
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
    final defaultColor = widget.barColor ?? AdminAppColors.primaryGreen;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(widget.title!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: AdminSpacing.md),
        ],
        SizedBox(
          height: widget.height,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return _buildChart(context, constraints, isDark, defaultColor);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, BoxConstraints constraints, bool isDark, Color defaultColor) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final maxValue = widget.data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final barWidth = (constraints.maxWidth - (widget.data.length + 1) * 8) / widget.data.length;
    final chartHeight = widget.height - 40; // Leave space for labels

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.data.length, (index) {
              final item = widget.data[index];
              final barHeight = maxValue > 0 ? (item.value / maxValue) * chartHeight * _animation.value : 0.0;
              final color = item.color ?? defaultColor;
              final isHovered = _hoveredIndex == index;

              return MouseRegion(
                onEnter: (_) => setState(() => _hoveredIndex = index),
                onExit: (_) => setState(() => _hoveredIndex = null),
                child: Tooltip(
                  message:
                      '${item.label}: ${widget.valuePrefix ?? ''}${item.value.toStringAsFixed(0)}${widget.valueSuffix ?? ''}',
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: barWidth.clamp(20, 80),
                    height: barHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [color, color.withOpacity(isHovered ? 0.9 : 0.7)],
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(6)),
                      boxShadow: isHovered
                          ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, -2))]
                          : null,
                    ),
                    child: widget.showValues && barHeight > 30
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                item.value.toStringAsFixed(0),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widget.data.map((item) {
            return SizedBox(
              width: barWidth.clamp(20, 80),
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? AdminAppColors.textSecondaryDark : AdminAppColors.textSecondaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
