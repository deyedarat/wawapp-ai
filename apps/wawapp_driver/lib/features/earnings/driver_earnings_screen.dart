import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core_shared/core_shared.dart';
import '../../models/order.dart' as app_order;
import '../../widgets/error_screen.dart';
import 'providers/driver_earnings_provider.dart';
import 'data/driver_earnings_repository.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final earningsState = ref.watch(driverEarningsProvider);
    final repository = DriverEarningsRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرباح'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'اليوم'),
            Tab(text: 'هذا الأسبوع'),
            Tab(text: 'إجمالي الأرباح'),
          ],
        ),
      ),
      body: earningsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : earningsState.error != null
              ? ErrorScreen(
                  message: AppError.from(earningsState.error!).toUserMessage(),
                  onRetry: () => ref.refresh(driverEarningsProvider),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDailyTab(earningsState, repository),
                    _buildWeeklyTab(earningsState, repository),
                    _buildTotalTab(earningsState),
                  ],
                ),
    );
  }

  Widget _buildDailyTab(
      DriverEarningsState state, DriverEarningsRepository repo) {
    final dailyOrders = repo.getDailyEarnings(state.completedOrders);
    final total = state.todayTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard('أرباح اليوم', '$total MRU', Colors.green,
              subtitle: '${dailyOrders.length} رحلة'),
          const SizedBox(height: 16),
          _buildTripsList(dailyOrders),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab(
      DriverEarningsState state, DriverEarningsRepository repo) {
    final weeklyOrders = repo.getWeeklyEarnings(state.completedOrders);
    final total = state.weekTotal;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard('أرباح هذا الأسبوع', '$total MRU', Colors.blue,
              subtitle: '${weeklyOrders.length} رحلة'),
          const SizedBox(height: 16),
          _buildTripsList(weeklyOrders),
        ],
      ),
    );
  }

  Widget _buildTotalTab(DriverEarningsState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(state),
          const SizedBox(height: 24),
          Text('جميع الرحلات المكتملة',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          _buildTripsList(state.completedOrders),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(DriverEarningsState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final todayCount = state.completedOrders.where((o) {
      final c = o.completedAt;
      return c != null && c.isAfter(today) && c.isBefore(tomorrow);
    }).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'أرباح اليوم',
                '${state.todayTotal} MRU',
                Colors.green,
                subtitle: '$todayCount رحلة',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'أرباح هذا الأسبوع',
                '${state.weekTotal} MRU',
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          'أرباح هذا الشهر',
          '${state.monthTotal} MRU',
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String amount, Color color,
      {String? subtitle}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) const SizedBox(height: 4),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsList(List<app_order.Order> orders) {
    if (orders.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text('لا توجد رحلات مكتملة'),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return _buildTripCard(order);
      },
    );
  }

  Widget _buildTripCard(app_order.Order order) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final fromAddress = _truncateAddress(order.pickup.label);
    final toAddress = _truncateAddress(order.dropoff.label);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.completedAt != null
                      ? dateFormat.format(order.completedAt!)
                      : 'غير محدد',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '${order.price} MRU',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(fromAddress,
                        style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.flag, size: 16, color: Colors.red),
                const SizedBox(width: 4),
                Expanded(
                    child:
                        Text(toAddress, style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${order.distanceKm.toStringAsFixed(1)} كم',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    return address.length > 30 ? '${address.substring(0, 30)}...' : address;
  }
}
