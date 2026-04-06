# Q TASK 6: Admin Stuck Orders View Panel

**Priority:** LOW 🟢
**Estimated Time:** 1.5 hours
**Difficulty:** Moderate

---

## Objective
Create an admin dashboard panel that shows orders stuck in `accepted` status for more than 5 minutes, allowing admins to monitor and intervene manually.

---

## What It Does

**For Admins:**
- See all orders in `accepted` status > 5 minutes
- View driver name, customer name, time stuck
- See pickup → dropoff route
- **View only** - no automatic actions
- Admin decides manually what to do (call driver, reassign, etc.)

---

## File to Create

### `apps/wawapp_admin/lib/features/orders/stuck_orders_panel.dart`

---

## Implementation

### Create the Widget

Create new file with this complete implementation:

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows orders stuck in 'accepted' status for > 5 minutes
/// Admins can view these orders and decide on manual intervention
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
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Query orders stuck in 'accepted' status for > 5 minutes
  Stream<List<Order>> _getStuckOrders() {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));

    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .where('acceptedAt', isLessThan: Timestamp.fromDate(fiveMinutesAgo))
        .orderBy('acceptedAt', descending: false) // Oldest first
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Order.fromFirestoreWithId(doc.id, doc.data()))
          .toList();
    });
  }

  /// Fetch driver name from Firestore
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
    } catch (e) {
      return 'خطأ';
    }
  }

  /// Fetch customer name from Firestore
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
    } catch (e) {
      return 'خطأ';
    }
  }

  /// Calculate how long order has been stuck (in minutes)
  int _calculateStuckMinutes(DateTime? acceptedAt) {
    if (acceptedAt == null) return 0;
    return DateTime.now().difference(acceptedAt).inMinutes;
  }

  /// Get color based on stuck duration
  Color _getStuckColor(int minutes) {
    if (minutes > 15) return Colors.red;
    if (minutes > 10) return Colors.orange;
    return Colors.amber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات العالقة'),
        subtitle: const Text('طلبات مقبولة لأكثر من 5 دقائق دون بدء الرحلة'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: StreamBuilder<List<Order>>(
        stream: _getStuckOrders(),
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جارِ التحميل...'),
                ],
              ),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

          // Empty state
          if (stuckOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد طلبات عالقة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'جميع الطلبات المقبولة تسير بشكل طبيعي',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Data table
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.orange.shade700, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'عدد الطلبات العالقة: ${stuckOrders.length}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'هذه الطلبات تحتاج متابعة - قد يحتاج السائق للمساعدة',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Orders table
                DataTable(
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
                    final stuckMinutes = _calculateStuckMinutes(order.createdAt);
                    final stuckColor = _getStuckColor(stuckMinutes);

                    return DataRow(
                      cells: [
                        // Order ID
                        DataCell(
                          Text(
                            '#${order.id?.substring(0, 6) ?? 'N/A'}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),

                        // Driver Name
                        DataCell(
                          FutureBuilder<String>(
                            future: _getDriverName(order.assignedDriverId),
                            builder: (context, snap) {
                              return Text(snap.data ?? '...');
                            },
                          ),
                        ),

                        // Customer Name
                        DataCell(
                          FutureBuilder<String>(
                            future: _getCustomerName(order.ownerId),
                            builder: (context, snap) {
                              return Text(snap.data ?? '...');
                            },
                          ),
                        ),

                        // Stuck Duration
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: stuckColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: stuckColor),
                            ),
                            child: Text(
                              '$stuckMinutes دقيقة',
                              style: TextStyle(
                                color: stuckColor.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        // Route
                        DataCell(
                          SizedBox(
                            width: 200,
                            child: Text(
                              '${_truncate(order.pickup.label, 20)} → ${_truncate(order.dropoff.label, 20)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),

                        // Price
                        DataCell(
                          Text(
                            '${order.price} MRU',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),

                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                onPressed: () {
                                  // TODO: Navigate to order details
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('عرض تفاصيل الطلب #${order.id?.substring(0, 6)}'),
                                    ),
                                  );
                                },
                                tooltip: 'عرض التفاصيل',
                              ),
                              IconButton(
                                icon: const Icon(Icons.phone, size: 20),
                                onPressed: () {
                                  // TODO: Call driver
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('الاتصال بالسائق')),
                                  );
                                },
                                tooltip: 'اتصل بالسائق',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Truncate text to max length
  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
```

---

## Integration

### Add to Admin Orders Screen

In your admin app, add a tab or route to this panel:

```dart
// Example: In admin orders screen tabs
TabBarView(
  children: [
    AllOrdersTab(),
    StuckOrdersPanel(),  // ADD THIS TAB
    CompletedOrdersTab(),
  ],
)
```

---

## Features

✅ **Real-time updates:**
- Stream-based (updates automatically)
- Auto-refresh every 30 seconds

✅ **Color coding:**
- 🟡 5-10 minutes: Yellow/Amber
- 🟠 10-15 minutes: Orange
- 🔴 15+ minutes: Red

✅ **Data shown:**
- Order ID (short)
- Driver name
- Customer name
- Time stuck (in minutes)
- Pickup → Dropoff route
- Price

✅ **Actions:**
- View details (placeholder)
- Call driver (placeholder)

---

## Testing Checklist

- [ ] Accept order as driver (don't start trip)
- [ ] Wait 5 minutes
- [ ] Open admin panel → order appears in stuck orders table
- [ ] Check color: 5-10 min → yellow
- [ ] Wait 10 minutes → color changes to orange
- [ ] Wait 15 minutes → color changes to red
- [ ] Driver starts trip → order disappears from panel
- [ ] Multiple stuck orders → all shown in table
- [ ] Empty state displays when no stuck orders
- [ ] flutter analyze → 0 errors

---

## Safety Rules

✅ **DO:**
- Show view-only data
- Let admin decide action manually
- Handle missing data gracefully (driver/customer names)

❌ **DON'T:**
- Auto-reassign orders
- Auto-cancel orders
- Modify order status automatically

---

## Future Enhancements (Not Required Now)

- Add "Call Driver" button integration with `url_launcher`
- Add "Manually Reassign" button (calls Cloud Function)
- Add export to CSV for reporting
- Add filters (by time range, driver, etc.)

---

## Verification

```bash
cd apps/wawapp_admin
flutter analyze
```

Expected: **0 errors**

---

## Report Back to Claude

✅ Created: `apps/wawapp_admin/lib/features/orders/stuck_orders_panel.dart`
✅ Features: Real-time stream, color coding, driver/customer names
✅ Test: Orders stuck > 5 min appear in table
✅ Test: Colors change based on duration
✅ Test: Empty state shows when no stuck orders
✅ `flutter analyze`: 0 errors

---

**Ready to start? Copy this entire task and paste to Amazon Q!**
