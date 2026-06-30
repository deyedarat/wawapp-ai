import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/components.dart';
import 'providers/order_history_provider.dart';

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final ordersAsync = ref.watch(orderHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.order_history),
        leading: IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => context.pop()),
      ),
      body: ordersAsync.when(
        loading: () => const WawLoadingIndicator(),
        error: (error, _) => WawEmptyState(
          icon: Icons.error_outline,
          title: l10n.error_loading_data,
          action: WawActionButton(
            label: l10n.retry,
            isFullWidth: false,
            onPressed: () => ref.invalidate(orderHistoryProvider),
          ),
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return WawEmptyState(
              icon: Icons.local_shipping_outlined,
              title: l10n.no_past_orders,
              message: l10n.start_your_first_shipment,
              action: WawActionButton(label: l10n.begin_shipment, isFullWidth: false, onPressed: () => context.go('/')),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderHistoryCard(order: order, theme: theme, l10n: l10n);
            },
          );
        },
      ),
    );
  }
}

class _OrderHistoryCard extends StatelessWidget {
  final Order order;
  final ThemeData theme;
  final AppLocalizations l10n;

  const _OrderHistoryCard({required this.order, required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final status = order.orderStatus;
    final statusColor = _getStatusColor(status);
    final dateFormat = DateFormat('HH:mm - dd/MM/yyyy');

    return InkWell(
      onTap: () {
        if (order.id != null) {
          context.push('/track/${order.id}');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge + date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(status), size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        status.toArabicLabel(),
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Date
                if (order.createdAt != null)
                  Text(
                    dateFormat.format(order.createdAt!),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Pickup address
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                ),
                const SizedBox(width: 8),
                Text(
                  'من: ',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.green, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    order.pickupAddress,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Dropoff address
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
                ),
                const SizedBox(width: 8),
                Text(
                  'إلى: ',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Text(
                    order.dropoffAddress,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Distance + Price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Distance
                Row(
                  children: [
                    Icon(Icons.route, size: 16, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${order.distanceKm.toStringAsFixed(1)} كم',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
                    ),
                  ],
                ),
                // Price
                Text(
                  '${order.price.toInt()} أوقية',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelledByClient:
      case OrderStatus.cancelledByDriver:
      case OrderStatus.cancelledBySystem:
      case OrderStatus.cancelledByAdmin:
        return Colors.red;
      case OrderStatus.expired:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelledByClient:
      case OrderStatus.cancelledByDriver:
      case OrderStatus.cancelledBySystem:
      case OrderStatus.cancelledByAdmin:
        return Icons.cancel;
      case OrderStatus.expired:
        return Icons.timer_off;
      default:
        return Icons.info;
    }
  }
}
