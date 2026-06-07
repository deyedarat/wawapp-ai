import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import '../orders/create_order_screen.dart';
import '../orders/order_detail_screen.dart';

/// Dashboard screen showing order statistics and recent activity.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<LaundryAuthProvider>();
    final ordersProvider = context.watch<OrdersProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(authProvider.currentUser?.name ?? 'لوحة التحكم'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final user = authProvider.currentUser;
          if (user != null) {
            ordersProvider.initializeForLaundry(user.uid);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Stats Cards
              _buildStatsSection(context, ordersProvider),
              const SizedBox(height: 24),

              // Revenue Card
              _buildRevenueCard(context, ordersProvider, authProvider),
              const SizedBox(height: 24),

              // Recent Orders
              _buildRecentOrders(context, ordersProvider),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
        },
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد'),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, OrdersProvider ordersProvider) {
    final stats = ordersProvider.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'إحصائيات اليوم',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'قيد الانتظار',
                value: '${stats['pending'] ?? 0}',
                icon: Icons.hourglass_empty,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'جاهزة',
                value: '${stats['ready'] ?? 0}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'مسلّمة',
                value: '${stats['delivered'] ?? 0}',
                icon: Icons.done_all,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueCard(
    BuildContext context,
    OrdersProvider ordersProvider,
    LaundryAuthProvider authProvider,
  ) {
    final deliveredToday = ordersProvider.deliveredTodayOrders;
    final todayRevenue = deliveredToday.fold(0.0, (sum, o) => sum + o.finalPrice);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                const Text(
                  'إيرادات اليوم',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Formatters.formatPrice(todayRevenue),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${deliveredToday.length} طلب مسلّم',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, OrdersProvider ordersProvider) {
    final pendingOrders = ordersProvider.pendingOrders;
    final readyOrders = ordersProvider.readyOrders;

    final urgentOrders = [...readyOrders, ...pendingOrders].take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'طلبات تحتاج انتباهك',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {
                // Switch to orders tab
              },
              child: const Text('عرض الكل'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (urgentOrders.isEmpty)
          const EmptyStateWidget(
            message: 'لا توجد طلبات حالياً',
            icon: Icons.inbox_outlined,
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: urgentOrders.length,
            itemBuilder: (context, index) {
              final order = urgentOrders[index];
              return _OrderListItem(
                order: order,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(order: order),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderListItem extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderListItem({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
          child: const Icon(
            Icons.local_laundry_service,
            color: Color(0xFF1B5E20),
          ),
        ),
        title: Text(
          order.customerName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${order.totalItems} قطعة - ${Formatters.formatPrice(order.finalPrice)}',
        ),
        trailing: StatusBadge(status: order.status, compact: true),
      ),
    );
  }
}
