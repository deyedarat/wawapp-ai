import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
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
      appBar: AppBar(title: Text(l10n.order_history)),
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
            padding: const EdgeInsets.all(WawAppSpacing.md),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: WawAppSpacing.sm),
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
    final dateFormat = DateFormat('dd/MM/yyyy - HH:mm');

    return WawCard(
      onTap: () {
        if (order.id != null) {
          context.push('/track/${order.id}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + date row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              WawStatusBadge(label: status.toArabicLabel(), color: statusColor, icon: _getStatusIcon(status)),
              if (order.createdAt != null)
                Text(
                  dateFormat.format(order.createdAt!),
                  style: theme.textTheme.bodySmall?.copyWith(color: WawAppColors.textSecondaryLight),
                ),
            ],
          ),
          const SizedBox(height: WawAppSpacing.sm),

          // Route info
          _buildRouteRow(icon: Icons.circle, iconColor: Colors.green, text: order.pickupAddress),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 11),
            child: Container(width: 2, height: 16, color: theme.dividerColor),
          ),
          _buildRouteRow(icon: Icons.circle, iconColor: Colors.red, text: order.dropoffAddress),

          const SizedBox(height: WawAppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: WawAppSpacing.sm),

          // Price + distance row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.payments_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${order.price.toInt()} ${l10n.currency}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.route, size: 18, color: WawAppColors.textSecondaryLight),
                  const SizedBox(width: 4),
                  Text(
                    '${order.distanceKm.toStringAsFixed(1)} ${l10n.km}',
                    style: theme.textTheme.bodySmall?.copyWith(color: WawAppColors.textSecondaryLight),
                  ),
                ],
              ),
              if (order.driverRating != null)
                Row(
                  children: [
                    const Icon(Icons.star, size: 18, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      '${order.driverRating}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteRow({required IconData icon, required Color iconColor, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 10, color: iconColor),
        const SizedBox(width: WawAppSpacing.xs),
        Expanded(
          child: Text(text, style: theme.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
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
