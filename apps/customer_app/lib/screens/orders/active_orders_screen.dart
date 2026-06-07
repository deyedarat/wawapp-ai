import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';
import 'order_detail_screen.dart';

/// Screen showing the customer's active orders.
class ActiveOrdersScreen extends StatelessWidget {
  const ActiveOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        actions: [
          Consumer<CustomerAuthProvider>(
            builder: (context, auth, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Center(
                  child: Text(
                    'مرحباً ${auth.currentUser?.name ?? ""}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<CustomerOrdersProvider>(
        builder: (context, ordersProvider, _) {
          if (ordersProvider.isLoading) {
            return const LoadingWidget(message: 'جاري تحميل الطلبات...');
          }

          final activeOrders = ordersProvider.activeOrders;

          if (activeOrders.isEmpty) {
            return const EmptyStateWidget(
              message: 'لا توجد طلبات نشطة حالياً\nعند تسليم ملابسك للمغسلة ستظهر هنا',
              icon: Icons.local_laundry_service_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final user = context.read<CustomerAuthProvider>().currentUser;
              if (user != null) {
                ordersProvider.initializeForCustomer(user.uid);
              }
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activeOrders.length,
              itemBuilder: (context, index) {
                final order = activeOrders[index];
                return _ActiveOrderCard(
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
            ),
          );
        },
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _ActiveOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
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
                    Formatters.formatOrderNumber(order.id),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                  StatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Indicator
              _buildProgressBar(context),
              const SizedBox(height: 16),

              // Items summary
              Row(
                children: [
                  const Icon(Icons.checkroom, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('${order.totalItems} قطعة'),
                  const Spacer(),
                  Text(
                    Formatters.formatPrice(order.finalPrice),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Estimated time
              if (order.status != OrderStatus.ready)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: order.estimatedCompletionTime
                                .isBefore(DateTime.now())
                            ? Colors.red
                            : const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'الموعد المتوقع: ${Formatters.formatDateTime(order.estimatedCompletionTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: order.estimatedCompletionTime
                                  .isBefore(DateTime.now())
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'ملابسك جاهزة! يمكنك استلامها الآن',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    double progress;
    switch (order.status) {
      case OrderStatus.received:
        progress = 0.25;
        break;
      case OrderStatus.washing:
        progress = 0.5;
        break;
      case OrderStatus.ready:
        progress = 0.75;
        break;
      case OrderStatus.delivered:
        progress = 1.0;
        break;
      case OrderStatus.cancelled:
        progress = 0;
        break;
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(
              order.status == OrderStatus.ready
                  ? Colors.green
                  : const Color(0xFF1565C0),
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepLabel('استلام', order.status.index >= 0),
            _buildStepLabel('غسيل', order.status.index >= 1),
            _buildStepLabel('جاهز', order.status.index >= 2),
            _buildStepLabel('تسليم', order.status.index >= 3),
          ],
        ),
      ],
    );
  }

  Widget _buildStepLabel(String label, bool isActive) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: isActive ? const Color(0xFF1565C0) : Colors.grey,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
