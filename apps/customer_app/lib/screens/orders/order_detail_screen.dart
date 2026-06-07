import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';
import '../../providers/orders_provider.dart';

/// Order detail screen for the customer app.
class CustomerOrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const CustomerOrderDetailScreen({super.key, required this.order});

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
            // Status Card with Timeline
            _buildStatusCard(context),
            const SizedBox(height: 16),

            // Items
            _buildItemsCard(context),
            const SizedBox(height: 16),

            // Time Info
            _buildTimeCard(context),
            const SizedBox(height: 16),

            // Price
            _buildPriceCard(context),
            const SizedBox(height: 16),

            // Notes
            if (order.notes != null && order.notes!.isNotEmpty)
              _buildNotesCard(context),

            // Rating (if delivered and not yet rated)
            if (order.status == OrderStatus.delivered && order.rating == null)
              _buildRatingSection(context),

            // Show existing rating
            if (order.rating != null) _buildExistingRating(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _getStatusColor().withOpacity(0.1),
              ),
              child: Icon(
                _getStatusIcon(),
                size: 40,
                color: _getStatusColor(),
              ),
            ),
            const SizedBox(height: 16),
            StatusBadge(status: order.status),
            const SizedBox(height: 8),
            Text(
              _getStatusMessage(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Timeline
            _buildTimeline(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    final steps = [
      _TimelineStep(
        title: 'تم الاستلام',
        subtitle: Formatters.formatDateTime(order.createdAt),
        isCompleted: true,
        isActive: order.status == OrderStatus.received,
      ),
      _TimelineStep(
        title: 'قيد الغسيل',
        subtitle: order.status.index >= 1 ? 'جاري العمل على ملابسك' : '',
        isCompleted: order.status.index >= 1,
        isActive: order.status == OrderStatus.washing,
      ),
      _TimelineStep(
        title: 'جاهزة للاستلام',
        subtitle: order.completedAt != null
            ? Formatters.formatDateTime(order.completedAt!)
            : '',
        isCompleted: order.status.index >= 2,
        isActive: order.status == OrderStatus.ready,
      ),
      _TimelineStep(
        title: 'تم التسليم',
        subtitle: order.deliveredAt != null
            ? Formatters.formatDateTime(order.deliveredAt!)
            : '',
        isCompleted: order.status == OrderStatus.delivered,
        isActive: order.status == OrderStatus.delivered,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.isCompleted
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade300,
                    border: step.isActive
                        ? Border.all(color: const Color(0xFF1565C0), width: 3)
                        : null,
                  ),
                  child: step.isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: step.isCompleted
                        ? const Color(0xFF1565C0)
                        : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontWeight: step.isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: step.isCompleted ? null : Colors.grey,
                      ),
                    ),
                    if (step.subtitle.isNotEmpty)
                      Text(
                        step.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
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
                const Icon(Icons.checkroom, color: Color(0xFF1565C0)),
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
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(item.type.arabicName),
                      const SizedBox(width: 8),
                      Text(
                        '×${item.quantity}',
                        style: TextStyle(color: Colors.grey[600]),
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
                const Text('تاريخ الاستلام:'),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context) {
    return Card(
      color: const Color(0xFF1565C0).withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'المبلغ الإجمالي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(
              Formatters.formatPrice(order.finalPrice),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
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
                Text('ملاحظات', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'قيّم الخدمة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('كيف كانت تجربتك مع هذا الطلب؟'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showRatingDialog(context),
                icon: const Icon(Icons.star),
                label: const Text('تقييم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExistingRating(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'تقييمك',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              RatingBarIndicator(
                rating: order.rating!.toDouble(),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                itemCount: 5,
                itemSize: 24,
              ),
              if (order.ratingComment != null && order.ratingComment!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    order.ratingComment!,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    double rating = 4;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('قيّم الخدمة', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingBar.builder(
                initialRating: 4,
                minRating: 1,
                direction: Axis.horizontal,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (value) {
                  rating = value;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'أضف تعليقاً (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final authProvider = context.read<CustomerAuthProvider>();
                final ordersProvider = context.read<CustomerOrdersProvider>();

                final success = await ordersProvider.rateOrder(
                  orderId: order.id,
                  customerId: authProvider.currentUser!.uid,
                  laundryId: order.laundryId,
                  rating: rating.toInt(),
                  comment: commentController.text.isNotEmpty
                      ? commentController.text
                      : null,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }

                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('شكراً لتقييمك!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('إرسال'),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (order.status) {
      case OrderStatus.received:
        return Colors.orange;
      case OrderStatus.washing:
        return const Color(0xFF1565C0);
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.delivered:
        return Colors.purple;
      case OrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    switch (order.status) {
      case OrderStatus.received:
        return Icons.receipt_long;
      case OrderStatus.washing:
        return Icons.local_laundry_service;
      case OrderStatus.ready:
        return Icons.check_circle;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  String _getStatusMessage() {
    switch (order.status) {
      case OrderStatus.received:
        return 'تم استلام ملابسك وهي في الانتظار';
      case OrderStatus.washing:
        return 'يتم غسل ملابسك الآن';
      case OrderStatus.ready:
        return 'ملابسك جاهزة! يمكنك استلامها الآن';
      case OrderStatus.delivered:
        return 'تم تسليم ملابسك بنجاح';
      case OrderStatus.cancelled:
        return 'تم إلغاء هذا الطلب';
    }
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
  });
}
