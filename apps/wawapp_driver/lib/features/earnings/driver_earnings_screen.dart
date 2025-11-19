import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart' as app_order;
import 'providers/driver_earnings_provider.dart';

class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earningsState = ref.watch(driverEarningsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الأرباح'),
        centerTitle: true,
      ),
      body: earningsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : earningsState.error != null
              ? Center(child: Text('خطأ: ${earningsState.error}'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCards(earningsState),
                      const SizedBox(height: 24),
                      Text(
                        'الرحلات المكتملة',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      _buildTripsList(earningsState.completedOrders),
                    ],
                  ),
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
