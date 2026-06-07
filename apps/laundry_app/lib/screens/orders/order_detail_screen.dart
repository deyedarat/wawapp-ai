import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/orders_provider.dart';

/// Screen showing detailed information about a specific order.
class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب ${Formatters.formatOrderNumber(order.id)}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            _buildStatusCard(context),
            const SizedBox(height: 16),

            // Customer Info
            _buildCustomerCard(context),
            const SizedBox(height: 16),

            // Items List
            _buildItemsCard(context),
            const SizedBox(height: 16),

            // Time Info
            _buildTimeCard(context),
            const SizedBox(height: 16),

            // Price Summary
            _buildPriceCard(context),
            const SizedBox(height: 16),

            // Notes
            if (order.notes != null && order.notes!.isNotEmpty)
              _buildNotesCard(context),
            const SizedBox(height: 24),

            // Action Buttons
            if (order.isActive) _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            StatusBadge(status: order.status),
            const SizedBox(height: 16),
            // Status Timeline
            _buildStatusTimeline(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context) {
    final statuses = [
      OrderStatus.received,
      OrderStatus.washing,
      OrderStatus.ready,
      OrderStatus.delivered,
    ];

    final currentIndex = statuses.indexOf(order.status);

    return Row(
      children: List.generate(statuses.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 3,
              color: stepIndex < currentIndex
                  ? const Color(0xFF1B5E20)
                  : Colors.grey.shade300,
            ),
          );
        }

        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex <= currentIndex;
        final isCurrent = stepIndex == currentIndex;

        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFF1B5E20) : Colors.grey.shade300,
            border: isCurrent
                ? Border.all(color: const Color(0xFF1B5E20), width: 3)
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : null,
            size: 16,
            color: Colors.white,
          ),
        );
      }),
    );
  }

  Widget _buildCustomerCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              child: Icon(Icons.person),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    Formatters.formatPhoneDisplay(order.customerPhone),
                    style: TextStyle(color: Colors.grey[600]),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.phone, color: Color(0xFF1B5E20)),
              onPressed: () {
                // TODO: Launch phone dialer
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checkroom, color: Color(0xFF1B5E20)),
                const SizedBox(width: 8),
                Text(
                  'القطع (${order.totalItems})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(item.type.arabicName),
                      const SizedBox(width: 8),
                      Text(
                        '×${item.quantity}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      Text(
                        Formatters.formatPrice(item.totalPrice),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('تاريخ الإنشاء:'),
                const Spacer(),
                Text(Formatters.formatDateTime(order.createdAt)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 18,
                  color: order.estimatedCompletionTime.isBefore(DateTime.now()) &&
                          order.isActive
                      ? Colors.red
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text('الموعد المتوقع:'),
                const Spacer(),
                Text(
                  Formatters.formatDateTime(order.estimatedCompletionTime),
                  style: TextStyle(
                    color:
                        order.estimatedCompletionTime.isBefore(DateTime.now()) &&
                                order.isActive
                            ? Colors.red
                            : null,
                  ),
                ),
              ],
            ),
            if (order.completedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('تاريخ الإنجاز:'),
                  const Spacer(),
                  Text(Formatters.formatDateTime(order.completedAt!)),
                ],
              ),
            ],
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.done_all, size: 18, color: Colors.purple),
                  const SizedBox(width: 8),
                  const Text('تاريخ التسليم:'),
                  const Spacer(),
                  Text(Formatters.formatDateTime(order.deliveredAt!)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context) {
    return Card(
      color: const Color(0xFF1B5E20).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المجموع'),
                Text(Formatters.formatPrice(order.totalPrice)),
              ],
            ),
            if (order.discount != null && order.discount! > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الخصم'),
                  Text(
                    '- ${Formatters.formatPrice(order.discount!)}',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  Formatters.formatPrice(order.finalPrice),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.note, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'ملاحظات',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Consumer<OrdersProvider>(
      builder: (context, ordersProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (order.status == OrderStatus.received)
              ElevatedButton.icon(
                onPressed: () => _updateStatus(context, OrderStatus.washing),
                icon: const Icon(Icons.local_laundry_service),
                label: const Text('بدء الغسيل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (order.status == OrderStatus.washing)
              ElevatedButton.icon(
                onPressed: () => _updateStatus(context, OrderStatus.ready),
                icon: const Icon(Icons.check_circle),
                label: const Text('تحديد كجاهز'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (order.status == OrderStatus.ready)
              ElevatedButton.icon(
                onPressed: () => _updateStatus(context, OrderStatus.delivered),
                icon: const Icon(Icons.done_all),
                label: const Text('تحديد كمسلّم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            if (order.status != OrderStatus.delivered) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _updateStatus(context, OrderStatus.cancelled),
                icon: const Icon(Icons.cancel, color: Colors.red),
                label: const Text('إلغاء الطلب',
                    style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _updateStatus(BuildContext context, OrderStatus newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد'),
        content: Text(
          'هل تريد تغيير حالة الطلب إلى "${newStatus.arabicName}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context
          .read<OrdersProvider>()
          .updateOrderStatus(order.id, newStatus);

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث حالة الطلب'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }
}
