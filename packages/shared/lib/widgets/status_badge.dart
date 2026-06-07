import 'package:flutter/material.dart';
import '../models/order_model.dart';

/// A badge widget displaying the order status with appropriate color.
class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  final String locale;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.status,
    this.locale = 'ar',
    this.compact = false,
  });

  Color get _backgroundColor {
    switch (status) {
      case OrderStatus.received:
        return const Color(0xFFFFF3E0);
      case OrderStatus.washing:
        return const Color(0xFFE3F2FD);
      case OrderStatus.ready:
        return const Color(0xFFE8F5E9);
      case OrderStatus.delivered:
        return const Color(0xFFF3E5F5);
      case OrderStatus.cancelled:
        return const Color(0xFFFFEBEE);
    }
  }

  Color get _textColor {
    switch (status) {
      case OrderStatus.received:
        return const Color(0xFFE65100);
      case OrderStatus.washing:
        return const Color(0xFF1565C0);
      case OrderStatus.ready:
        return const Color(0xFF2E7D32);
      case OrderStatus.delivered:
        return const Color(0xFF6A1B9A);
      case OrderStatus.cancelled:
        return const Color(0xFFC62828);
    }
  }

  IconData get _icon {
    switch (status) {
      case OrderStatus.received:
        return Icons.receipt_long;
      case OrderStatus.washing:
        return Icons.local_laundry_service;
      case OrderStatus.ready:
        return Icons.check_circle;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: compact ? 14 : 16,
            color: _textColor,
          ),
          const SizedBox(width: 4),
          Text(
            status.getLocalizedName(locale),
            style: TextStyle(
              color: _textColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
