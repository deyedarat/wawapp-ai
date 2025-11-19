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
    OrderStatus.completed,
  ];

  int _indexOf(OrderStatus s) {
    final index = _steps.indexOf(s);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final current = _indexOf(status);
    final isSmallScreen = MediaQuery.of(context).size.width < 400;

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicWidth(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_steps.length, (i) {
                final active = i <= current;
                return SizedBox(
                  width: 80,
                  child: Column(
                    children: [
                      Container(
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade700,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _steps[i].toArabicLabel(),
                        style: isSmallScreen
                            ? Theme.of(context).textTheme.labelSmall
                            : Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
