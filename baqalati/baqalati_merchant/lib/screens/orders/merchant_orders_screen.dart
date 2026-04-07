import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';

class MerchantOrdersScreen extends StatelessWidget {
  const MerchantOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final ordersProvider = context.watch<OrdersProvider>();
    final storeId = context.read<AuthProvider>().user?.storeId ?? 'store_1';
    final orders = ordersProvider.getStoreOrders(storeId);

    // Sort: pending first, then by date
    final sortedOrders = List<OrderModel>.from(orders)
      ..sort((a, b) {
        if (a.status == OrderStatus.pending && b.status != OrderStatus.pending) {
          return -1;
        }
        if (a.status != OrderStatus.pending && b.status == OrderStatus.pending) {
          return 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('incoming_orders')),
        automaticallyImplyLeading: false,
      ),
      body: ordersProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sortedOrders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        l10n.tr('no_orders'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedOrders.length,
                  itemBuilder: (context, index) {
                    final order = sortedOrders[index];
                    return _buildOrderCard(
                      context, order, l10n, localeProvider, ordersProvider,
                    );
                  },
                ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    AppLocalizations l10n,
    LocaleProvider localeProvider,
    OrdersProvider ordersProvider,
  ) {
    final statusColor = AppTheme.getStatusColor(order.status.name);
    final isPending = order.status == OrderStatus.pending;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending
            ? const BorderSide(color: AppTheme.pending, width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (isPending)
                      Container(
                        margin: EdgeInsets.only(
                          left: localeProvider.isArabic ? 8 : 0,
                          right: localeProvider.isArabic ? 0 : 8,
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          color: AppTheme.pending,
                          size: 20,
                        ),
                      ),
                    Text(
                      order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.tr('status_${order.status.name}'),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Customer Info
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppTheme.grey),
                const SizedBox(width: 6),
                Text(order.userName,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                if (order.userPhone.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.phone, size: 16, color: AppTheme.grey),
                  const SizedBox(width: 4),
                  Text(
                    order.userPhone,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 8),

            // Delivery Type
            Row(
              children: [
                Icon(
                  order.deliveryType == DeliveryType.delivery
                      ? Icons.delivery_dining
                      : Icons.store,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(width: 6),
                Text(
                  order.deliveryType == DeliveryType.delivery
                      ? l10n.tr('delivery')
                      : l10n.tr('pickup'),
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            if (order.deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppTheme.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],

            const Divider(height: 20),

            // Items
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.getLocalizedName(localeProvider.languageCode)} x${item.quantity}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${item.total.toStringAsFixed(0)} ${l10n.tr('mru')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )),

            const Divider(height: 16),

            // Total & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${l10n.tr('total')}: ${order.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                Text(
                  _formatTime(order.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),

            // Status Update Buttons
            if (order.status != OrderStatus.delivered &&
                order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusButton(
                      context,
                      order,
                      ordersProvider,
                      l10n,
                    ),
                  ),
                  if (order.status == OrderStatus.pending) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () {
                          _confirmCancelOrder(
                              context, order, ordersProvider, l10n);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                        ),
                        child: Text(l10n.tr('cancel')),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(
    BuildContext context,
    OrderModel order,
    OrdersProvider ordersProvider,
    AppLocalizations l10n,
  ) {
    OrderStatus nextStatus;
    String buttonText;
    Color buttonColor;

    switch (order.status) {
      case OrderStatus.pending:
        nextStatus = OrderStatus.preparing;
        buttonText = l10n.tr('status_preparing');
        buttonColor = AppTheme.preparing;
        break;
      case OrderStatus.preparing:
        nextStatus = OrderStatus.ready;
        buttonText = l10n.tr('status_ready');
        buttonColor = AppTheme.ready;
        break;
      case OrderStatus.ready:
        nextStatus = OrderStatus.delivered;
        buttonText = l10n.tr('status_delivered');
        buttonColor = AppTheme.delivered;
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: () {
          ordersProvider.updateOrderStatus(order.id, nextStatus);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.tr('order_updated')),
              backgroundColor: buttonColor,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        icon: Icon(AppTheme.getStatusIcon(nextStatus.name), size: 18),
        label: Text('${l10n.tr('update_status')}: $buttonText'),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  void _confirmCancelOrder(
    BuildContext context,
    OrderModel order,
    OrdersProvider ordersProvider,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('cancel')),
        content: Text(l10n.tr('confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.tr('no')),
          ),
          TextButton(
            onPressed: () {
              ordersProvider.updateOrderStatus(
                  order.id, OrderStatus.cancelled);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.tr('status_cancelled')),
                  backgroundColor: AppTheme.error,
                ),
              );
            },
            child: Text(
              l10n.tr('yes'),
              style: const TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
