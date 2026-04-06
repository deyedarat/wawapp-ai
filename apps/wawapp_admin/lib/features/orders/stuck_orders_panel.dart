import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

/// Shows orders stuck in 'accepted' status for > 5 minutes.
/// View-only — admin decides manually what to do.
class StuckOrdersPanel extends ConsumerStatefulWidget {
  const StuckOrdersPanel({super.key});

  @override
  ConsumerState<StuckOrdersPanel> createState() => _StuckOrdersPanelState();
}

class _StuckOrdersPanelState extends ConsumerState<StuckOrdersPanel> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Stream<List<Order>> _getStuckOrders() {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .where('acceptedAt', isLessThan: Timestamp.fromDate(fiveMinutesAgo))
        .orderBy('acceptedAt')
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => Order.fromFirestoreWithId(doc.id, doc.data()))
            .toList());
  }

  Future<String> _getDriverName(String? driverId) async {
    if (driverId == null) return 'غير معيّن';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .get();
      if (!doc.exists) return 'سائق #${driverId.substring(0, 6)}';
      final data = doc.data();
      return data?['displayName'] as String? ??
          data?['phoneNumber'] as String? ??
          'سائق #${driverId.substring(0, 6)}';
    } catch (_) {
      return 'خطأ';
    }
  }

  Future<String> _getCustomerName(String? ownerId) async {
    if (ownerId == null) return 'غير معيّن';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerId)
          .get();
      if (!doc.exists) return 'عميل #${ownerId.substring(0, 6)}';
      final data = doc.data();
      return data?['displayName'] as String? ??
          data?['phoneNumber'] as String? ??
          'عميل #${ownerId.substring(0, 6)}';
    } catch (_) {
      return 'خطأ';
    }
  }

  int _stuckMinutes(DateTime? acceptedAt) {
    if (acceptedAt == null) return 0;
    return DateTime.now().difference(acceptedAt).inMinutes;
  }

  Color _stuckColor(int minutes) {
    if (minutes > 15) return AdminAppColors.errorLight;
    if (minutes > 10) return AdminAppColors.warningLight;
    return AdminAppColors.pendingYellow;
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'الطلبات العالقة',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => setState(() {}),
          tooltip: 'تحديث',
        ),
      ],
      child: StreamBuilder<List<Order>>(
        stream: _getStuckOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AdminAppColors.errorLight),
                  const SizedBox(height: 16),
                  Text('خطأ: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            );
          }

          final stuckOrders = snapshot.data ?? [];

          if (stuckOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: AdminAppColors.successLight),
                  const SizedBox(height: 16),
                  const Text('لا توجد طلبات عالقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('جميع الطلبات المقبولة تسير بشكل طبيعي', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AdminSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 32),
                        const SizedBox(width: AdminSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'عدد الطلبات العالقة: ${stuckOrders.length}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'طلبات مقبولة لأكثر من 5 دقائق دون بدء الرحلة',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AdminSpacing.md),

                // Orders table
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AdminAppColors.backgroundLight),
                      columns: const [
                        DataColumn(label: Text('رقم الطلب')),
                        DataColumn(label: Text('السائق')),
                        DataColumn(label: Text('العميل')),
                        DataColumn(label: Text('مدة التعليق')),
                        DataColumn(label: Text('المسار')),
                        DataColumn(label: Text('السعر')),
                        DataColumn(label: Text('الإجراءات')),
                      ],
                      rows: stuckOrders.map((order) {
                        final minutes = _stuckMinutes(order.createdAt);
                        final color = _stuckColor(minutes);

                        return DataRow(cells: [
                          DataCell(Text(
                            '#${order.id?.substring(0, 6) ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                          )),
                          DataCell(FutureBuilder<String>(
                            future: _getDriverName(order.assignedDriverId),
                            builder: (_, snap) => Text(snap.data ?? '...'),
                          )),
                          DataCell(FutureBuilder<String>(
                            future: _getCustomerName(order.ownerId),
                            builder: (_, snap) => Text(snap.data ?? '...'),
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(AdminSpacing.radiusXs),
                              border: Border.all(color: color),
                            ),
                            child: Text(
                              '$minutes دقيقة',
                              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          )),
                          DataCell(SizedBox(
                            width: 200,
                            child: Text(
                              '${_truncate(order.pickup.label, 20)} → ${_truncate(order.dropoff.label, 20)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                          DataCell(Text(
                            '${order.price.toStringAsFixed(0)} MRU',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AdminAppColors.primaryGreen),
                          )),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                tooltip: 'عرض التفاصيل',
                                color: AdminAppColors.infoLight,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('عرض تفاصيل الطلب #${order.id?.substring(0, 6)}')),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone, size: 20),
                                tooltip: 'اتصل بالسائق',
                                color: AdminAppColors.primaryGreen,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('الاتصال بالسائق')),
                                  );
                                },
                              ),
                            ],
                          )),
                        ]);
                      }).toList(),
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
}
