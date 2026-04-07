import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();
    final ordersProvider = context.watch<OrdersProvider>();
    final productsProvider = context.watch<ProductsProvider>();
    final storeId = context.read<AuthProvider>().user?.storeId ?? 'store_1';

    final allOrders = ordersProvider.getStoreOrders(storeId);
    final todayOrders = ordersProvider.getStoreTodayOrders(storeId);
    final todayRevenue = ordersProvider.getStoreTodayRevenue(storeId);

    // Calculate stats
    final totalRevenue = allOrders
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (sum, o) => sum + o.totalAmount);

    final deliveryOrders =
        allOrders.where((o) => o.deliveryType == DeliveryType.delivery).length;
    final pickupOrders =
        allOrders.where((o) => o.deliveryType == DeliveryType.pickup).length;

    final pendingOrders =
        allOrders.where((o) => o.status == OrderStatus.pending).length;
    final preparingOrders =
        allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final readyOrders =
        allOrders.where((o) => o.status == OrderStatus.ready).length;
    final deliveredOrders =
        allOrders.where((o) => o.status == OrderStatus.delivered).length;
    final cancelledOrders =
        allOrders.where((o) => o.status == OrderStatus.cancelled).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('statistics')),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Today Summary
            Text(
              localeProvider.isArabic ? 'ملخص اليوم' : 'Résumé du jour',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.receipt_long,
                    title: l10n.tr('today_orders'),
                    value: '${todayOrders.length}',
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    title: l10n.tr('today_revenue'),
                    value: '${todayRevenue.toStringAsFixed(0)}',
                    subtitle: l10n.tr('mru'),
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Overall Stats
            Text(
              localeProvider.isArabic ? 'إحصائيات عامة' : 'Statistiques générales',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_bag,
                    title: localeProvider.isArabic
                        ? 'إجمالي الطلبات'
                        : 'Total commandes',
                    value: '${allOrders.length}',
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.monetization_on,
                    title: localeProvider.isArabic
                        ? 'إجمالي الإيرادات'
                        : 'Revenus totaux',
                    value: totalRevenue.toStringAsFixed(0),
                    subtitle: l10n.tr('mru'),
                    color: AppTheme.primaryGreenDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_2,
                    title: l10n.tr('total_products'),
                    value: '${productsProvider.totalProducts}',
                    color: AppTheme.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    title: localeProvider.isArabic
                        ? 'منتجات متوفرة'
                        : 'Produits disponibles',
                    value: '${productsProvider.availableProducts}',
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Order Status Breakdown
            Text(
              localeProvider.isArabic
                  ? 'توزيع حالات الطلبات'
                  : 'Répartition des statuts',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildStatusRow(
                      l10n.tr('status_pending'),
                      pendingOrders,
                      allOrders.length,
                      AppTheme.pending,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      l10n.tr('status_preparing'),
                      preparingOrders,
                      allOrders.length,
                      AppTheme.preparing,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      l10n.tr('status_ready'),
                      readyOrders,
                      allOrders.length,
                      AppTheme.ready,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      l10n.tr('status_delivered'),
                      deliveredOrders,
                      allOrders.length,
                      AppTheme.delivered,
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow(
                      l10n.tr('status_cancelled'),
                      cancelledOrders,
                      allOrders.length,
                      AppTheme.cancelled,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Delivery Type Breakdown
            Text(
              localeProvider.isArabic
                  ? 'طريقة الاستلام'
                  : 'Mode de réception',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildDeliveryRow(
                      Icons.delivery_dining,
                      l10n.tr('delivery'),
                      deliveryOrders,
                      allOrders.length,
                      AppTheme.info,
                    ),
                    const SizedBox(height: 16),
                    _buildDeliveryRow(
                      Icons.store,
                      l10n.tr('pickup'),
                      pickupOrders,
                      allOrders.length,
                      AppTheme.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: color.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 14)),
              ],
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryRow(
    IconData icon,
    String label,
    int count,
    int total,
    Color color,
  ) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
