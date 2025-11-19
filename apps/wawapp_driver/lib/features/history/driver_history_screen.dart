import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart' as app_order;
import 'providers/history_providers.dart';

class DriverHistoryScreen extends ConsumerWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(driverHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات المنتهية'),
        centerTitle: true,
      ),
      body: historyAsync.when(
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(
              child: Text('لا توجد طلبات منتهية'),
            );
          }

          return ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return _OrderHistoryTile(order: order);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ في تحميل البيانات: $error'),
        ),
      ),
    );
  }
}

class _OrderHistoryTile extends StatelessWidget {
  final app_order.Order order;

  const _OrderHistoryTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final completedDate = order.completedAt != null 
        ? dateFormat.format(order.completedAt!)
        : 'غير محدد';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text('طلب #${order.id.substring(0, 8)}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.pickup.label} ← ${order.dropoff.label}'),
            Text('تاريخ الإنتهاء: $completedDate'),
          ],
        ),
        trailing: Text(
          '${order.price} MRU',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        onTap: () {
          context.pushNamed('orderDetails', extra: order);
        },
      ),
    );
  }
}