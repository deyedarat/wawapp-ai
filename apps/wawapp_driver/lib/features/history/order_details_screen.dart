import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart' as app_order;

class OrderDetailsScreen extends StatelessWidget {
  final app_order.Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${order.id.substring(0, 8)}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              'معلومات الطلب',
              [
                _buildInfoRow('رقم الطلب', order.id.substring(0, 8)),
                _buildInfoRow('الحالة', 'مكتمل'),
                _buildInfoRow('السعر', '${order.price} MRU'),
                _buildInfoRow('المسافة', '${order.distanceKm.toStringAsFixed(1)} كم'),
                if (order.completedAt != null)
                  _buildInfoRow('تاريخ الإكمال', dateFormat.format(order.completedAt!)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoCard(
              'تفاصيل الرحلة',
              [
                _buildLocationRow('نقطة الانطلاق', order.pickup.label, Icons.location_on, Colors.green),
                const SizedBox(height: 8),
                _buildLocationRow('الوجهة', order.dropoff.label, Icons.flag, Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String address, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}