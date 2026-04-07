import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/orders_provider.dart';
import '../../theme/app_theme.dart';
import '../tracking/order_tracking_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdersProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ordersProvider = context.watch<OrdersProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('my_orders')),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text:
                  '${l10n.tr('status_preparing')} (${ordersProvider.activeOrders.length})',
            ),
            Tab(
              text:
                  '${l10n.tr('status_delivered')} (${ordersProvider.completedOrders.length})',
            ),
          ],
        ),
      ),
      body: ordersProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOrdersList(
                  context,
                  ordersProvider.activeOrders,
                  l10n,
                  isEmpty: ordersProvider.activeOrders.isEmpty,
                ),
                _buildOrdersList(
                  context,
                  ordersProvider.completedOrders,
                  l10n,
                  isEmpty: ordersProvider.completedOrders.isEmpty,
                ),
              ],
            ),
    );
  }

  Widget _buildOrdersList(
    BuildContext context,
    List<OrderModel> orders,
    AppLocalizations l10n, {
    bool isEmpty = false,
  }) {
    if (isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              l10n.tr('no_orders'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.tr('no_orders_subtitle'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildOrderCard(context, order, l10n);
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    AppLocalizations l10n,
  ) {
    final localeProvider = context.watch<LocaleProvider>();
    final statusColor = AppTheme.getStatusColor(order.status.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderTrackingScreen(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.ltr,
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

              const SizedBox(height: 8),

              // Store Name
              Row(
                children: [
                  const Icon(Icons.storefront, size: 16, color: AppTheme.grey),
                  const SizedBox(width: 6),
                  Text(
                    order.storeName,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Items summary
              Text(
                order.items
                    .map((item) =>
                        '${item.getLocalizedName(localeProvider.languageCode)} x${item.quantity}')
                    .join('، '),
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const Divider(height: 16),

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(order.createdAt),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    '${order.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
