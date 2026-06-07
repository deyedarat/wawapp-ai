import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/orders_provider.dart';
import 'order_detail_screen.dart';

/// Screen showing the customer's order history.
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
      ),
      body: Consumer<CustomerOrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.isLoading) {
            return const LoadingWidget();
          }

          final history = ordersProvider.orderHistory;

          if (history.isEmpty) {
            return const EmptyStateWidget(
              message: 'لا يوجد سجل طلبات بعد',
              icon: Icons.history,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.length,
            itemBuilder: (context, index) {
              final order = history[index];
              return _HistoryOrderCard(
                order: order,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CustomerOrderDetailScreen(order: order),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _HistoryOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    Formatters.formatOrderNumber(order.id),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                  StatusBadge(status: order.status, compact: true),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.checkroom, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${order.totalItems} قطعة'),
                  const Spacer(),
                  Text(
                    Formatters.formatPrice(order.finalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    Formatters.formatDate(order.createdAt),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  if (order.rating != null) ...[
                    const Spacer(),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < order.rating! ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
