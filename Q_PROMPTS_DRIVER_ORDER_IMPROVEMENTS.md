# Amazon Q Implementation Prompts - Driver Order Management Improvements

**Project:** WawApp Driver App Order Management Enhancement
**Supervisor:** Claude Code
**Executor:** Amazon Q Developer
**Language:** Code and commits in English, UI in Arabic

---

## **IMPORTANT: Read CLAUDE.md First**
Before executing ANY prompt below, Amazon Q MUST read and follow:
- `c:\Users\hp\Music\wawapp-ai\CLAUDE.md` (Global safety rules)
- All safety rules from Section 1-7

**Critical Rules:**
- ✅ Edit ONLY what is explicitly requested
- ✅ Add dependencies to pubspec.yaml/package.json
- ✅ NO placeholders or dummy data
- ✅ Preserve functional requirements
- ✅ Run `flutter analyze` after each change
- ❌ NO assumptions
- ❌ NO refactoring unless asked

---

## **Q TASK 1: Hide Accepted Orders from Nearby Screen**

### Prompt for Amazon Q:

```
TASK: Filter out accepted orders from the driver's nearby orders screen.

CONTEXT:
- File: apps/wawapp_driver/lib/features/nearby/providers/nearby_orders_provider.dart
- Currently shows all orders with status='matching'
- Problem: Orders that are already accepted (assignedDriverId != null) should not appear

REQUIREMENTS:
1. In the nearby_orders_provider.dart, after fetching orders from getNearbyOrders service
2. Add a filter to remove orders where:
   - assignedDriverId != null OR
   - status != 'matching'

IMPLEMENTATION:
Find the line where rawOrders are processed and add:

final filteredOrders = rawOrders.where((order) {
  return order.assignedDriverId == null && order.status == 'matching';
}).toList();

TESTING:
- Accept an order → verify it disappears from nearby screen immediately
- Cancel order (back to matching) → verify it reappears

SAFETY:
- Preserve existing error handling
- Keep all logging statements
- Don't modify getNearbyOrders Cloud Function

EXPECTED OUTPUT:
- Modified file: apps/wawapp_driver/lib/features/nearby/providers/nearby_orders_provider.dart
- No new dependencies
- flutter analyze: 0 errors
```

---

## **Q TASK 2: Change Reminder Interval to 5 Minutes**

### Prompt for Amazon Q:

```
TASK: Change trip start reminder interval from 1 minute to 5 minutes.

CONTEXT:
- File: functions/src/monitorAcceptedOrders.ts
- Currently sends reminders every 1 minute after driver accepts order
- User wants 5-minute intervals instead

REQUIREMENTS:
1. Find line 22: const REMINDER_INTERVAL_MINUTES = 1;
2. Change to: const REMINDER_INTERVAL_MINUTES = 5;
3. No other changes needed (idempotency logic already in place)

TESTING:
- Accept an order
- Wait 5 minutes → verify reminder notification arrives
- Wait 10 minutes → verify second reminder arrives
- Check Firestore: lastReminderSentAt field updates correctly

DEPLOYMENT:
After modification, run:
cd functions
npm run build
firebase deploy --only functions:monitorAcceptedOrders

EXPECTED OUTPUT:
- Modified file: functions/src/monitorAcceptedOrders.ts (1 line change)
- No new dependencies
- npm run build: success
```

---

## **Q TASK 3: Create Driver Cancellation Flow with Reasons**

### Prompt for Amazon Q (Part A: Data Model):

```
TASK 3A: Add cancellation reason enum to core_shared package.

CONTEXT:
- Package: packages/core_shared/lib/src/
- Need to support structured cancellation reasons for analytics

REQUIREMENTS:
1. Create new file: packages/core_shared/lib/src/cancel_reason.dart

CODE:
enum CancelReason {
  vehicleBreakdown,
  customerNotReachable,
  customerRequested,
  other;

  String toFirestore() {
    switch (this) {
      case CancelReason.vehicleBreakdown:
        return 'vehicle_breakdown';
      case CancelReason.customerNotReachable:
        return 'customer_not_reachable';
      case CancelReason.customerRequested:
        return 'customer_requested';
      case CancelReason.other:
        return 'other';
    }
  }

  static CancelReason fromFirestore(String value) {
    switch (value) {
      case 'vehicle_breakdown':
        return CancelReason.vehicleBreakdown;
      case 'customer_not_reachable':
        return CancelReason.customerNotReachable;
      case 'customer_requested':
        return CancelReason.customerRequested;
      case 'other':
        return CancelReason.other;
      default:
        throw ArgumentError('Unknown cancel reason: $value');
    }
  }

  String toArabicLabel() {
    switch (this) {
      case CancelReason.vehicleBreakdown:
        return 'تعطل السيارة';
      case CancelReason.customerNotReachable:
        return 'الزبون لا يرد على الهاتف';
      case CancelReason.customerRequested:
        return 'الزبون طلب الإلغاء';
      case CancelReason.other:
        return 'سبب آخر';
    }
  }
}

2. Export in: packages/core_shared/lib/core_shared.dart
   Add: export 'src/cancel_reason.dart';

EXPECTED OUTPUT:
- New file: packages/core_shared/lib/src/cancel_reason.dart
- Modified: packages/core_shared/lib/core_shared.dart
- flutter analyze: 0 errors
```

### Prompt for Amazon Q (Part B: UI Dialog):

```
TASK 3B: Create cancellation reason selection dialog.

CONTEXT:
- App: apps/wawapp_driver
- Location: lib/features/active/widgets/
- Replace simple yes/no dialog with reason selection

REQUIREMENTS:
1. Create new file: apps/wawapp_driver/lib/features/active/widgets/cancel_order_dialog.dart

CODE STRUCTURE:
- StatefulWidget with orderId parameter
- Radio buttons for each CancelReason
- Disabled "تأكيد الإلغاء" button until reason selected
- Cancel button to dismiss
- Returns selected CancelReason or null

DEPENDENCIES:
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';

UI LAYOUT:
AlertDialog(
  title: Text('ما هو سبب الإلغاء؟'),
  content: SingleChildScrollView(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final reason in CancelReason.values)
          RadioListTile<CancelReason>(
            title: Text(reason.toArabicLabel()),
            value: reason,
            groupValue: _selectedReason,
            onChanged: (val) => setState(() => _selectedReason = val),
          ),
      ],
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text('إلغاء'),
    ),
    ElevatedButton(
      onPressed: _selectedReason != null
        ? () => Navigator.pop(context, _selectedReason)
        : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: DriverAppColors.accentRed,
      ),
      child: Text('تأكيد الإلغاء'),
    ),
  ],
)

EXPECTED OUTPUT:
- New file: apps/wawapp_driver/lib/features/active/widgets/cancel_order_dialog.dart
- flutter analyze: 0 errors
```

### Prompt for Amazon Q (Part C: Integrate Dialog):

```
TASK 3C: Integrate cancellation dialog into ActiveOrderScreen.

CONTEXT:
- File: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- Current _showCancelDialog() shows simple yes/no
- Need to show CancelOrderDialog instead and pass reason to service

REQUIREMENTS:
1. Import the new dialog:
   import 'widgets/cancel_order_dialog.dart';

2. Replace _showCancelDialog() method (lines 61-84):

Future<void> _showCancelDialog(String orderId) async {
  final reason = await showDialog<CancelReason>(
    context: context,
    builder: (context) => CancelOrderDialog(orderId: orderId),
  );

  if (reason != null && mounted) {
    await _cancelOrder(orderId, reason);
  }
}

3. Update _cancelOrder() signature (line 86):

Future<void> _cancelOrder(String orderId, CancelReason reason) async {
  setState(() => _isCancelling = true);

  try {
    final ordersService = ref.read(ordersServiceProvider);
    await ordersService.cancelOrder(orderId, reason: reason);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم إلغاء الطلب: ${reason.toArabicLabel()}')),
      );
    }
  } on Object catch (e) {
    if (mounted) {
      setState(() => _isCancelling = false);
      final message = e.toString().contains('current status')
          ? 'لا يمكن إلغاء الطلب الآن، ربما تغيّرت حالته.'
          : 'تعذّر إلغاء الطلب، حاول مرة أخرى.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}

TESTING:
- Press cancel button → dialog appears with 4 reasons
- Select reason → confirm button enabled
- Press confirm → order cancelled with reason

EXPECTED OUTPUT:
- Modified: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- flutter analyze: 0 errors
```

### Prompt for Amazon Q (Part D: Update Service):

```
TASK 3D: Update OrdersService to accept cancellation reason.

CONTEXT:
- File: apps/wawapp_driver/lib/services/orders_service.dart
- Current cancelOrder() doesn't accept reason parameter
- Need to add optional reason parameter and pass to Firestore

REQUIREMENTS:
1. Update cancelOrder() method signature (line 145):

Future<void> cancelOrder(String orderId, {CancelReason? reason}) async {

2. In the transaction update (line 173-176), add reason fields:

transaction.update(
  orderRef,
  {
    ...OrderStatus.cancelledByDriver.createTransitionUpdate(),
    if (reason != null) 'cancelReason': reason.toFirestore(),
    if (reason != null) 'cancelledByDriverAt': FieldValue.serverTimestamp(),
  },
);

TESTING:
- Cancel order with reason → verify Firestore document has 'cancelReason' field
- Cancel without reason (backward compat) → no error

EXPECTED OUTPUT:
- Modified: apps/wawapp_driver/lib/services/orders_service.dart
- flutter analyze: 0 errors
```

### Prompt for Amazon Q (Part E: Backend - Return to Matching):

```
TASK 3E: Create Cloud Function to handle driver cancellation with reason.

CONTEXT:
- When driver cancels, order should return to 'matching' status (search for new driver)
- Need to notify customer with reason
- Track cancellation in Firestore

REQUIREMENTS:
1. Create new file: functions/src/handleDriverCancellation.ts

CODE:
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';

export const handleDriverCancellation = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const orderId = context.params.orderId;

    // Detect driver cancellation
    const wasCancelled =
      beforeData.status !== 'cancelledByDriver' &&
      afterData.status === 'cancelledByDriver' &&
      afterData.cancelReason !== undefined;

    if (!wasCancelled) {
      return null;
    }

    const cancelReason = afterData.cancelReason as string;
    const previousDriverId = afterData.assignedDriverId || afterData.driverId;
    const ownerId = afterData.ownerId;

    console.log('[HandleDriverCancellation] Driver cancelled order', {
      order_id: orderId,
      driver_id: previousDriverId,
      reason: cancelReason,
    });

    try {
      // Return order to matching pool
      await change.after.ref.update({
        status: 'matching',
        assignedDriverId: null,
        driverId: null,
        previousDriverId: previousDriverId,
        reassignedAt: admin.firestore.FieldValue.serverTimestamp(),
        reassignReason: `driver_cancelled_${cancelReason}`,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify customer
      if (ownerId) {
        const userDoc = await admin.firestore().collection('users').doc(ownerId).get();
        const fcmToken = userDoc.data()?.fcmToken;

        if (fcmToken) {
          let reasonArabic = 'السائق ألغى الطلب';
          switch (cancelReason) {
            case 'vehicle_breakdown':
              reasonArabic = 'تعطل سيارة السائق';
              break;
            case 'customer_not_reachable':
              reasonArabic = 'لم يتمكن السائق من الوصول إليك';
              break;
            case 'customer_requested':
              reasonArabic = 'تم الإلغاء بناءً على طلبك';
              break;
          }

          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: 'تم إلغاء الطلب',
              body: `السبب: ${reasonArabic}. جارِ البحث عن سائق آخر...`,
            },
            data: {
              notificationType: 'order_cancelled_by_driver',
              orderId: orderId,
              reason: cancelReason,
            },
            android: { priority: 'high' },
          });
        }
      }

      console.log('[HandleDriverCancellation] Order returned to matching', {
        order_id: orderId,
        previous_driver: previousDriverId,
      });

    } catch (error) {
      console.error('[HandleDriverCancellation] Error:', error);
    }

    return null;
  });

2. Export in functions/src/index.ts:
   export { handleDriverCancellation } from './handleDriverCancellation';

DEPLOYMENT:
cd functions
npm run build
firebase deploy --only functions:handleDriverCancellation

TESTING:
- Driver cancels order → order status changes to matching
- Customer receives notification with reason
- New drivers can see and accept the order

EXPECTED OUTPUT:
- New file: functions/src/handleDriverCancellation.ts
- Modified: functions/src/index.ts
- npm run build: success
```

---

## **Q TASK 4: Add Customer Phone Number Display**

### Prompt for Amazon Q (Part A: Backend):

```
TASK 4A: Add customer phone to order document on acceptance.

CONTEXT:
- File: functions/src/acceptOrder.ts
- When driver accepts order, fetch customer phone and add to order doc
- This allows driver to see and call customer

REQUIREMENTS:
1. In acceptOrder.ts, after successful order acceptance (after transaction completes)
2. Fetch customer phone from users collection
3. Update order document with customerPhone field

IMPLEMENTATION:
Find the transaction block (around line 100-150) and modify:

// Inside the transaction, after setting assignedDriverId:
const customerDoc = await transaction.get(
  admin.firestore().collection('users').doc(orderData.ownerId)
);

const customerPhone = customerDoc.exists
  ? (customerDoc.data()?.phoneNumber as string | null)
  : null;

transaction.update(orderRef, {
  status: 'accepted',
  assignedDriverId: driverId,
  driverId: driverId,
  acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
  customerPhone: customerPhone, // ADD THIS
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
});

SECURITY:
- Phone only added when order is accepted (not before)
- Only assigned driver can see customerPhone (enforce in Firestore rules)

TESTING:
- Accept order → check Firestore document has customerPhone field
- Field should be customer's actual phone number

EXPECTED OUTPUT:
- Modified: functions/src/acceptOrder.ts
- npm run build: success
```

### Prompt for Amazon Q (Part B: Data Model):

```
TASK 4B: Add customerPhone field to Order model.

CONTEXT:
- File: packages/core_shared/lib/src/order.dart
- Need to parse customerPhone from Firestore

REQUIREMENTS:
1. Add field to Order class (around line 37):

final String? customerPhone;

2. Add to constructor parameters:

const Order({
  ...
  this.customerPhone,
  ...
});

3. Update fromFirestore factory (line 63):

customerPhone: data['customerPhone'] as String?,

4. Update fromFirestoreWithId factory (line 94):

customerPhone: data['customerPhone'] as String?,

5. Update toMap() method (line 123):

'customerPhone': customerPhone,

6. Update copyWith() method (line 144):

String? customerPhone,

... and in return statement:

customerPhone: customerPhone ?? this.customerPhone,

TESTING:
- flutter analyze: 0 errors
- No breaking changes to existing code

EXPECTED OUTPUT:
- Modified: packages/core_shared/lib/src/order.dart
- flutter analyze: 0 errors
```

### Prompt for Amazon Q (Part C: UI Display):

```
TASK 4C: Display customer phone prominently in ActiveOrderScreen.

CONTEXT:
- File: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- Currently shows TODO for phone number (line 304-310)
- Need to display actual phone with call button

REQUIREMENTS:
1. Replace the TODO IconButton section (lines 299-311) with:

// Customer phone card
if (order.customerPhone != null)
  Card(
    color: DriverAppColors.primaryLight.withOpacity(0.1),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.phone,
            color: DriverAppColors.primaryLight,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رقم العميل',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  order.customerPhone!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _makePhoneCall(order.customerPhone!),
            icon: const Icon(Icons.call),
            label: const Text('اتصل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  ),
const SizedBox(height: 12),

2. Place this BEFORE the pickup/dropoff location cards (before line 314)

VISUAL DESIGN:
- Large phone number in bold
- Green "اتصل" (Call) button
- Prominent placement at top of order details

TESTING:
- Accept order → phone number displays clearly
- Press call button → phone dialer opens with number

EXPECTED OUTPUT:
- Modified: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- flutter analyze: 0 errors
```

---

## **Q TASK 5: Update Notification Colors**

### Prompt for Amazon Q:

```
TASK: Add color coding to notifications (red for rejection, yellow for acceptance).

CONTEXT:
- File: apps/wawapp_driver/lib/services/notification_service.dart
- Currently all notifications use default colors
- Need color differentiation for better UX

REQUIREMENTS:
1. Create helper method to determine notification color (add after line 45):

Color _getNotificationColor(String notificationType) {
  switch (notificationType) {
    // Red for negative events
    case 'order_cancelled':
    case 'order_cancelled_by_driver':
    case 'timeout_expired':
    case 'insufficient_balance':
      return const Color(0xFFE53935); // Red

    // Yellow for new opportunities
    case 'new_order':
    case 'unassigned_order_reminder':
    case 'acceptance_confirmation':
      return const Color(0xFFFDD835); // Yellow

    // Blue for updates
    case 'trip_start_reminder':
    case 'order_update':
    default:
      return const Color(0xFF1976D2); // Blue
  }
}

2. Update _handleForegroundMessage() (line 191-207) to use color:

final color = _getNotificationColor(notificationType);

_localNotifications.show(
  notificationId,
  notification.title,
  notification.body,
  NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      color: color,            // ADD THIS
      colorized: true,         // ADD THIS
      enableVibration: true,
      playSound: true,
      onlyAlertOnce: true,
    ),
  ),
  payload: payload,
);

3. Update _showTripReminderNotification() (line 226-246):

final color = _getNotificationColor('trip_start_reminder');

// Add to AndroidNotificationDetails:
color: color,
colorized: true,

4. Update _showFullScreenNotification() (line 300-320):

final color = _getNotificationColor(type);

// Add to AndroidNotificationDetails:
color: color,
colorized: true,

TESTING:
- Receive new order notification → yellow notification icon
- Receive cancellation → red notification icon
- Receive reminder → blue notification icon

EXPECTED OUTPUT:
- Modified: apps/wawapp_driver/lib/services/notification_service.dart
- flutter analyze: 0 errors
```

---

## **Q TASK 6: Create Admin Stuck Orders View Panel**

### Prompt for Amazon Q:

```
TASK: Create admin panel to view stuck orders (accepted > 5 minutes without trip start).

CONTEXT:
- App: apps/wawapp_admin
- Location: lib/features/orders/
- Admins need visibility into stalled orders for manual intervention

REQUIREMENTS:
1. Create new file: apps/wawapp_admin/lib/features/orders/stuck_orders_panel.dart

FUNCTIONALITY:
- Query orders where:
  - status == 'accepted'
  - acceptedAt < now - 5 minutes
- Display in DataTable with columns:
  - Order ID (short)
  - Driver Name
  - Customer Name
  - Time Stuck (in minutes)
  - Pickup → Dropoff
  - Actions (View Details button)

- Refresh every 30 seconds automatically
- Show "No stuck orders" if empty

CODE STRUCTURE:
class StuckOrdersPanel extends ConsumerStatefulWidget {
  @override
  State<StuckOrdersPanel> createState() => _StuckOrdersPanelState();
}

class _StuckOrdersPanelState extends ConsumerState<StuckOrdersPanel> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(Duration(seconds: 30), (_) {
      setState(() {}); // Trigger rebuild
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Stream<List<Order>> _getStuckOrders() {
    final fiveMinutesAgo = DateTime.now().subtract(Duration(minutes: 5));

    return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'accepted')
      .where('acceptedAt', isLessThan: Timestamp.fromDate(fiveMinutesAgo))
      .orderBy('acceptedAt', descending: false)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
          .map((doc) => Order.fromFirestoreWithId(doc.id, doc.data()))
          .toList();
      });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: _getStuckOrders(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('خطأ: ${snapshot.error}'));
        }

        final stuckOrders = snapshot.data ?? [];

        if (stuckOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 64, color: Colors.green),
                SizedBox(height: 16),
                Text('لا توجد طلبات عالقة'),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          child: DataTable(
            columns: [
              DataColumn(label: Text('رقم الطلب')),
              DataColumn(label: Text('السائق')),
              DataColumn(label: Text('العميل')),
              DataColumn(label: Text('مدة التعليق')),
              DataColumn(label: Text('المسار')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: stuckOrders.map((order) {
              final stuckMinutes = DateTime.now()
                .difference(order.createdAt ?? DateTime.now())
                .inMinutes;

              return DataRow(cells: [
                DataCell(Text('#${order.id?.substring(0, 6) ?? 'N/A'}')),
                DataCell(FutureBuilder<String>(
                  future: _getDriverName(order.assignedDriverId),
                  builder: (context, snap) => Text(snap.data ?? '...'),
                )),
                DataCell(FutureBuilder<String>(
                  future: _getCustomerName(order.ownerId),
                  builder: (context, snap) => Text(snap.data ?? '...'),
                )),
                DataCell(Text(
                  '$stuckMinutes دقيقة',
                  style: TextStyle(
                    color: stuckMinutes > 10 ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                )),
                DataCell(Text(
                  '${order.pickup.label.substring(0, 20)}... → ${order.dropoff.label.substring(0, 20)}...',
                  overflow: TextOverflow.ellipsis,
                )),
                DataCell(IconButton(
                  icon: Icon(Icons.visibility),
                  onPressed: () {
                    // TODO: Navigate to order details
                  },
                )),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Future<String> _getDriverName(String? driverId) async {
    if (driverId == null) return 'غير معيّن';
    try {
      final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverId)
        .get();
      return doc.data()?['displayName'] ?? 'سائق #${driverId.substring(0, 6)}';
    } catch (e) {
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
      return doc.data()?['displayName'] ?? 'عميل #${ownerId.substring(0, 6)}';
    } catch (e) {
      return 'خطأ';
    }
  }
}

2. Add to admin orders screen as a tab

TESTING:
- Accept order as driver
- Wait 5 minutes without starting trip
- Check admin panel → order appears in stuck orders table
- Start trip → order disappears from panel

EXPECTED OUTPUT:
- New file: apps/wawapp_admin/lib/features/orders/stuck_orders_panel.dart
- flutter analyze: 0 errors
```

---

## **Q TASK 7: Improve Insufficient Balance UI Feedback**

### Prompt for Amazon Q:

```
TASK: Improve UI feedback when trip start fails due to insufficient wallet balance.

CONTEXT:
- File: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- Currently: When driver presses "بدء الرحلة" with insufficient balance:
  - Backend reverts order status to 'accepted'
  - Driver receives FCM notification
  - But UI might not handle status revert gracefully

PROBLEM:
- User reported "data loss" when pressing start trip button
- This is likely the insufficient balance revert scenario
- UI needs better feedback

REQUIREMENTS:
1. In _transition() method (line 41-59), add better error handling:

Future<void> _transition(String orderId, OrderStatus to) async {
  try {
    final ordersService = ref.read(ordersServiceProvider);
    await ordersService.transition(orderId, to);

    if (!mounted) return;

    // Success feedback
    String message = 'تم تحديث حالة الطلب';
    if (to == OrderStatus.onRoute) {
      message = 'تم بدء الرحلة بنجاح';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  } on Object catch (e) {
    if (!mounted) return;

    // Enhanced error messages
    String errorMessage = 'خطأ: ${e.toString()}';

    if (e.toString().contains('insufficient') ||
        e.toString().contains('balance')) {
      errorMessage = 'رصيد محفظتك غير كافٍ. يرجى الشحن أولاً.';
    } else if (e.toString().contains('current status')) {
      errorMessage = 'لا يمكن تحديث الطلب الآن، ربما تغيّرت حالته.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}

2. Add loading state to "بدء الرحلة" button:
   - Add bool _isStartingTrip = false;
   - Wrap button in loading state

TESTING:
- Low wallet balance scenario:
  - Accept order
  - Press start trip → see error message about insufficient balance
  - Order remains in accepted state (UI doesn't lose data)
  - User can navigate to wallet to top up

EXPECTED OUTPUT:
- Modified: apps/wawapp_driver/lib/features/active/active_order_screen.dart
- flutter analyze: 0 errors
```

---

## **EXECUTION ORDER**

Amazon Q should execute prompts in this sequence:

1. **Q TASK 1** (Hide accepted orders) - 15 min
2. **Q TASK 2** (Reminder interval) - 10 min
3. **Q TASK 3 (A→E)** (Cancellation flow) - 2 hours
4. **Q TASK 4 (A→C)** (Customer phone) - 1 hour
5. **Q TASK 5** (Notification colors) - 30 min
6. **Q TASK 6** (Admin panel) - 1.5 hours
7. **Q TASK 7** (Balance feedback) - 30 min

**Total Estimated Time: 6 hours**

---

## **TESTING CHECKLIST**

After all tasks complete, verify:

- [ ] Accepted orders don't appear in nearby screen
- [ ] Reminders arrive every 5 minutes (not 1 minute)
- [ ] Cancel dialog shows 4 reasons in Arabic
- [ ] Cancelled orders return to matching status
- [ ] Customer phone displays prominently after acceptance
- [ ] Call button opens phone dialer
- [ ] Notifications have correct colors (red/yellow/blue)
- [ ] Admin panel shows stuck orders > 5 min
- [ ] Insufficient balance error shows clear message
- [ ] No data loss in any scenario
- [ ] All tests pass: `flutter analyze` → 0 errors
- [ ] Backend deploys successfully

---

## **SUPERVISION BY CLAUDE**

After Amazon Q completes each task:
1. Report file changes to Claude
2. Claude will review code quality
3. Claude will verify CLAUDE.md compliance
4. Claude will approve or request fixes
5. Only then proceed to next task

**Do NOT skip supervision steps!**

---

## **DEPLOYMENT COMMANDS**

### Flutter Apps:
```bash
cd apps/wawapp_driver
flutter analyze
flutter build apk --release
```

### Cloud Functions:
```bash
cd functions
npm run build
firebase deploy --only functions
```

### Firestore Rules (if needed):
```bash
firebase deploy --only firestore:rules
```

---

## **ROLLBACK PLAN**

If anything breaks:
1. Revert last commit: `git revert HEAD`
2. Redeploy previous Cloud Functions version
3. Report issue to Claude
4. Fix and retry

---

**END OF PROMPTS**

Claude: Review this file and approve before Amazon Q starts execution.
