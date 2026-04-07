import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order_model.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class OrderTrackingScreen extends StatelessWidget {
  final OrderModel order;

  const OrderTrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeProvider = context.watch<LocaleProvider>();

    final steps = [
      _TrackingStep(
        status: OrderStatus.pending,
        titleKey: 'status_pending',
        icon: Icons.access_time,
        color: AppTheme.pending,
      ),
      _TrackingStep(
        status: OrderStatus.preparing,
        titleKey: 'status_preparing',
        icon: Icons.restaurant,
        color: AppTheme.preparing,
      ),
      _TrackingStep(
        status: OrderStatus.ready,
        titleKey: 'status_ready',
        icon: Icons.check_circle,
        color: AppTheme.ready,
      ),
      _TrackingStep(
        status: OrderStatus.delivered,
        titleKey: 'status_delivered',
        icon: Icons.done_all,
        color: AppTheme.delivered,
      ),
    ];

    final currentStepIndex = steps.indexWhere((s) => s.status == order.status);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('order_tracking')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order ID Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('order_id'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          order.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('order_date'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          _formatDate(order.createdAt),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('delivery_method'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            order.deliveryType == DeliveryType.delivery
                                ? l10n.tr('delivery')
                                : l10n.tr('pickup'),
                            style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Tracking Timeline
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('order_status'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(steps.length, (index) {
                      final step = steps[index];
                      final isCompleted = index <= currentStepIndex;
                      final isCurrent = index == currentStepIndex;
                      final isLast = index == steps.length - 1;

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicator
                          Column(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? step.color
                                      : Colors.grey[300],
                                  shape: BoxShape.circle,
                                  boxShadow: isCurrent
                                      ? [
                                          BoxShadow(
                                            color: step.color.withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  step.icon,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              if (!isLast)
                                Container(
                                  width: 3,
                                  height: 40,
                                  color: isCompleted && index < currentStepIndex
                                      ? step.color
                                      : Colors.grey[300],
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Step info
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.tr(step.titleKey),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isCompleted
                                          ? AppTheme.black
                                          : Colors.grey[400],
                                    ),
                                  ),
                                  if (isCurrent)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        _getStatusDescription(
                                            step.status, l10n),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  if (!isLast) const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order Items
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('order_summary'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.getLocalizedName(localeProvider.languageCode)} x${item.quantity}',
                                ),
                              ),
                              Text(
                                '${item.total.toStringAsFixed(0)} ${l10n.tr('mru')}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('total'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${order.totalAmount.toStringAsFixed(0)} ${l10n.tr('mru')}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusDescription(OrderStatus status, AppLocalizations l10n) {
    switch (status) {
      case OrderStatus.pending:
        return l10n.isArabic
            ? 'تم استلام طلبك وبانتظار التأكيد'
            : 'Votre commande a été reçue et est en attente de confirmation';
      case OrderStatus.preparing:
        return l10n.isArabic
            ? 'البقالة تقوم بتجهيز طلبك'
            : 'L\'épicerie prépare votre commande';
      case OrderStatus.ready:
        return l10n.isArabic
            ? 'طلبك جاهز للاستلام أو التوصيل'
            : 'Votre commande est prête pour le retrait ou la livraison';
      case OrderStatus.delivered:
        return l10n.isArabic
            ? 'تم تسليم طلبك بنجاح'
            : 'Votre commande a été livrée avec succès';
      case OrderStatus.cancelled:
        return l10n.isArabic
            ? 'تم إلغاء الطلب'
            : 'La commande a été annulée';
    }
  }
}

class _TrackingStep {
  final OrderStatus status;
  final String titleKey;
  final IconData icon;
  final Color color;

  _TrackingStep({
    required this.status,
    required this.titleKey,
    required this.icon,
    required this.color,
  });
}
