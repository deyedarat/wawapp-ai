import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderStatusScreen extends StatelessWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حالة الطلب')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          final driverId = data['driverId'] as String?;

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
                        Text('طلب #${orderId.substring(orderId.length - 6)}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('الحالة: ${_getStatusText(status)}'),
                        if (driverId != null) ...[
                          const SizedBox(height: 8),
                          const Text('تم تعيين سائق'),
                          _DriverLocationWidget(driverId: driverId),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'matching':
        return 'البحث عن سائق';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'onRoute':
        return 'السائق في الطريق';
      case 'completed':
        return 'تم إكمال الطلب';
      case 'cancelled':
        return 'تم إلغاء الطلب';
      default:
        return status;
    }
  }
}

class _DriverLocationWidget extends StatelessWidget {
  final String driverId;

  const _DriverLocationWidget({required this.driverId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('driver_locations')
          .doc(driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('موقع السائق غير متاح');
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('السائق في الطريق إليك'),
            if (updatedAt != null)
              Text('آخر تحديث: ${_formatTime(updatedAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    return 'منذ ${diff.inHours} ساعة';
  }
}
