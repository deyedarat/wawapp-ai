import 'package:flutter/material.dart';
import 'package:core_shared/core_shared.dart';

class OrderStatusTimeline extends StatelessWidget {
  final OrderStatus status;
  const OrderStatusTimeline({super.key, required this.status});

  static const List<OrderStatus> _steps = [
    OrderStatus.requested,
    OrderStatus.assigning,
    OrderStatus.accepted,
    OrderStatus.onRoute,
  ];

  int _indexOf(OrderStatus s) {
    // For completed, all steps are active
    if (s == OrderStatus.completed) return _steps.length;
    final index = _steps.indexOf(s);
    return index == -1 ? 0 : index;
  }

  IconData _iconForStep(OrderStatus step) {
    switch (step) {
      case OrderStatus.requested:
        return Icons.description_outlined;
      case OrderStatus.assigning:
        return Icons.person_outline;
      case OrderStatus.accepted:
        return Icons.person_search_outlined;
      case OrderStatus.onRoute:
        return Icons.local_shipping_outlined;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _indexOf(status);
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          // Icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (i) {
              final active = i <= current;
              return Icon(_iconForStep(_steps[i]), size: 22, color: active ? primaryColor : Colors.grey.shade600);
            }),
          ),
          const SizedBox(height: 4),
          // Labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_steps.length, (i) {
              final active = i <= current;
              return Flexible(
                child: Text(
                  _steps[i].toArabicLabel(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: active ? Colors.white : Colors.grey.shade600,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Progress line with dots
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isEven) {
                // Dot
                final stepIndex = i ~/ 2;
                final active = stepIndex <= current;
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? primaryColor : Colors.grey.shade700,
                    border: Border.all(color: active ? primaryColor : Colors.grey.shade600, width: 2),
                  ),
                );
              } else {
                // Line between dots
                final stepIndex = (i - 1) ~/ 2;
                final active = stepIndex < current;
                return Expanded(child: Container(height: 3, color: active ? primaryColor : Colors.grey.shade700));
              }
            }),
          ),
        ],
      ),
    );
  }
}
