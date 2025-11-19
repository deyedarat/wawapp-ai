import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import '../../models/order.dart' as app_order;
import '../../services/orders_service.dart';
import '../../services/tracking_service.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final _ordersService = OrdersService();
  bool _isTrackingStarted = false;

  @override
  void dispose() {
    if (_isTrackingStarted) {
      TrackingService.instance.stopTracking();
    }
    super.dispose();
  }

  Future<void> _transition(String orderId, OrderStatus to) async {
    try {
      await _ordersService.transition(orderId, to);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('غير مسجل الدخول')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الطلب النشط')),
      body: StreamBuilder<List<app_order.Order>>(
        stream: _ordersService.getDriverActiveOrders(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];

          // Handle tracking based on active orders
          if (orders.isNotEmpty && !_isTrackingStarted) {
            _isTrackingStarted = true;
            TrackingService.instance.startTracking();
          } else if (orders.isEmpty && _isTrackingStarted) {
            _isTrackingStarted = false;
            TrackingService.instance.stopTracking();
          }

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد طلبات نشطة'),
                ],
              ),
            );
          }

          final order = orders.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلب #${order.id.substring(order.id.length - 6)}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('من: ${order.pickup.label}'),
                        Text('إلى: ${order.dropoff.label}'),
                        Text(
                            'المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
                        Text('السعر: ${order.price} MRU'),
                        Text('الحالة: ${order.orderStatus.toArabicLabel()}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: order.orderStatus.canDriverStartTrip
                      ? () => _transition(order.id, OrderStatus.onRoute)
                      : null,
                  child: const Text('بدء الرحلة'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: order.orderStatus.canDriverCompleteTrip
                      ? () => _transition(order.id, OrderStatus.completed)
                      : null,
                  child: const Text('إكمال الطلب'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: order.orderStatus.canDriverCancel
                      ? () =>
                          _transition(order.id, OrderStatus.cancelledByDriver)
                      : null,
                  child: const Text('إلغاء'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
