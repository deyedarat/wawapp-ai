import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'providers/order_tracking_provider.dart';

class DriverFoundScreen extends ConsumerWidget {
  final String orderId;

  const DriverFoundScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('تم العثور على سائق')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('خطأ: $error'),
        ),
        data: (snapshot) {
          if (snapshot == null || !snapshot.exists) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final driverId = data['driverId'] as String?;
          final status = data['status'] as String?;

          return FutureBuilder<DocumentSnapshot>(
            future: driverId != null
                ? FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(driverId)
                    .get()
                : null,
            builder: (context, driverSnapshot) {
              final driverData = driverSnapshot.data?.data() as Map<String, dynamic>?;
              final driverName = driverData?['name'] as String? ?? 'السائق';
              final driverPhone = driverData?['phone'] as String? ?? '';
              final vehicle = driverData?['vehicle'] as String? ?? 'غير محدد';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
                    const SizedBox(height: 24),
                    const Text(
                      'تم قبول طلبك!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('السائق: $driverName',
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            if (driverPhone.isNotEmpty)
                              Text('الهاتف: $driverPhone',
                                  style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('المركبة: $vehicle',
                                style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('الحالة: ${status ?? "غير معروف"}',
                                style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.access_time),
                            SizedBox(width: 8),
                            Text('الوقت المتوقع للوصول: 5-10 دقائق',
                                style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/track/$orderId');
                      },
                      child: const Text('تتبع السائق'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
