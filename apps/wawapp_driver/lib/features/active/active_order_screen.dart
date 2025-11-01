import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart' as app_order;
import '../../services/orders_service.dart';

class ActiveOrderScreen extends StatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final _ordersService = OrdersService();

  Future<void> _transition(String orderId, app_order.OrderStatus to) async {
    try {
      await _ordersService.transition(orderId, to);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    } catch (e) {
      if (!mounted) return;
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
                        Text('الحالة: ${order.status}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (order.orderStatus == app_order.OrderStatus.accepted) ...[
                  ElevatedButton(
                    onPressed: () =>
                        _transition(order.id, app_order.OrderStatus.onRoute),
                    child: const Text('بدء الرحلة'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () =>
                        _transition(order.id, app_order.OrderStatus.cancelled),
                    child: const Text('إلغاء'),
                  ),
                ],
                if (order.orderStatus == app_order.OrderStatus.onRoute) ...[
                  ElevatedButton(
                    onPressed: () =>
                        _transition(order.id, app_order.OrderStatus.completed),
                    child: const Text('إكمال الطلب'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
