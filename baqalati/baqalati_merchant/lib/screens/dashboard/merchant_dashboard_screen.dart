import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/products_provider.dart';
import '../../theme/app_theme.dart';
import '../orders/merchant_orders_screen.dart';
import '../products/products_management_screen.dart';
import '../stats/stats_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final storeId =
          context.read<AuthProvider>().user?.storeId ?? 'store_1';
      context.read<OrdersProvider>().loadOrders();
      context.read<ProductsProvider>().loadProducts(storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final screens = [
      _buildDashboardTab(context, l10n),
      const MerchantOrdersScreen(),
      const ProductsManagementScreen(),
      const StatsScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: l10n.tr('merchant_dashboard'),
          ),
          BottomNavigationBarItem(
            icon: Consumer<OrdersProvider>(
              builder: (context, orders, _) {
                final storeId =
                    context.read<AuthProvider>().user?.storeId ?? 'store_1';
                final pendingCount = orders
                    .getStoreOrders(storeId)
                    .where((o) => o.status.name == 'pending')
                    .length;
                return Badge(
                  isLabelVisible: pendingCount > 0,
                  label: Text('$pendingCount'),
                  child: const Icon(Icons.receipt_long_outlined),
                );
              },
            ),
            activeIcon: const Icon(Icons.receipt_long),
            label: l10n.tr('incoming_orders'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            activeIcon: const Icon(Icons.inventory_2),
            label: l10n.tr('products'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bar_chart_outlined),
            activeIcon: const Icon(Icons.bar_chart),
            label: l10n.tr('statistics'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(BuildContext context, AppLocalizations l10n) {
    final localeProvider = context.watch<LocaleProvider>();
    final authProvider = context.watch<AuthProvider>();
    final ordersProvider = context.watch<OrdersProvider>();
    final productsProvider = context.watch<ProductsProvider>();
    final storeId = authProvider.user?.storeId ?? 'store_1';

    final todayOrders = ordersProvider.getStoreTodayOrders(storeId);
    final todayRevenue = ordersProvider.getStoreTodayRevenue(storeId);
    final pendingOrders = ordersProvider
        .getStoreOrders(storeId)
        .where((o) => o.status.name == 'pending')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('app_name_merchant')),
        backgroundColor: AppTheme.primaryGreenDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => localeProvider.toggleLocale(),
            tooltip: localeProvider.isArabic ? 'Français' : 'العربية',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authProvider.logout(),
            tooltip: l10n.tr('logout'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ordersProvider.loadOrders();
          await productsProvider.loadProducts(storeId);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome
              Text(
                '${localeProvider.isArabic ? "مرحباً" : "Bonjour"}, ${authProvider.user?.name ?? ""}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                localeProvider.isArabic
                    ? 'إليك ملخص نشاط بقالتك اليوم'
                    : 'Voici le résumé de l\'activité de votre épicerie aujourd\'hui',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 20),

              // Stats Cards
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
                      value: '${todayRevenue.toStringAsFixed(0)} ${l10n.tr('mru')}',
                      color: AppTheme.success,
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
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.pending_actions,
                      title: l10n.tr('status_pending'),
                      value: '${pendingOrders.length}',
                      color: AppTheme.pending,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Pending Orders
              if (pendingOrders.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l10n.tr('incoming_orders')} (${pendingOrders.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentIndex = 1),
                      child: Text(l10n.tr('all')),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...pendingOrders.take(3).map((order) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.pending.withOpacity(0.1),
                          child: const Icon(Icons.access_time,
                              color: AppTheme.pending),
                        ),
                        title: Text(
                          order.userName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${order.items.length} ${l10n.tr('products')} - ${order.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.pending.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            l10n.tr('status_pending'),
                            style: const TextStyle(
                              color: AppTheme.pending,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        onTap: () => setState(() => _currentIndex = 1),
                      ),
                    )),
              ],

              // Quick Actions
              const SizedBox(height: 24),
              Text(
                localeProvider.isArabic ? 'إجراءات سريعة' : 'Actions rapides',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.add_circle,
                      label: l10n.tr('add_product'),
                      color: AppTheme.primaryGreen,
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.receipt_long,
                      label: l10n.tr('incoming_orders'),
                      color: AppTheme.info,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickAction(
                      icon: Icons.bar_chart,
                      label: l10n.tr('statistics'),
                      color: AppTheme.pending,
                      onTap: () => setState(() => _currentIndex = 3),
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

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
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
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
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

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
