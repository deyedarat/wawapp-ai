# Amazon Q Prompts - Dispatch v2.0 Flutter Integration

هذا الملف يحتوي على **4 prompts منفصلة** لـ Amazon Q لتحديث تطبيق السائق Flutter.

**تعليمات التنفيذ:**
1. أعط Amazon Q كل prompt على حدة
2. انتظر حتى ينتهي من كل مرحلة
3. قم بـ `flutter analyze` للتحقق
4. إذا نجح، انتقل للـ prompt التالي
5. إذا فشل، أصلح الأخطاء ثم تابع

---

## 📦 Prompt 1: Create DispatchOffer Model

**Context:** We deployed a new backend dispatch system v2.0 that uses offer-based dispatch. We need to create a Flutter model for `DispatchOffer`.

**Task:** Create the following file with exact structure:

**File:** `apps/wawapp_driver/lib/features/orders/models/dispatch_offer.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a dispatch offer sent to a driver
///
/// Backend collection: dispatch_offers
/// ID format: {orderId}_{driverId}
class DispatchOffer {
  final String offerId;
  final String orderId;
  final String driverId;
  final String status; // 'sent', 'accepted', 'rejected', 'expired', 'cancelled'
  final int round; // Wave number (1, 2, 3)
  final int priority;
  final DateTime sentAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
  final double distance; // km from pickup location

  DispatchOffer({
    required this.offerId,
    required this.orderId,
    required this.driverId,
    required this.status,
    required this.round,
    required this.priority,
    required this.sentAt,
    required this.expiresAt,
    this.respondedAt,
    required this.distance,
  });

  /// Create from Firestore document
  factory DispatchOffer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DispatchOffer(
      offerId: doc.id,
      orderId: data['orderId'] as String,
      driverId: data['driverId'] as String,
      status: data['status'] as String,
      round: data['round'] as int,
      priority: data['priority'] as int,
      sentAt: (data['sentAt'] as Timestamp).toDate(),
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null
        ? (data['respondedAt'] as Timestamp).toDate()
        : null,
      distance: (data['distance'] as num).toDouble(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'offerId': offerId,
      'orderId': orderId,
      'driverId': driverId,
      'status': status,
      'round': round,
      'priority': priority,
      'sentAt': Timestamp.fromDate(sentAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'distance': distance,
    };
  }

  /// Check if offer is still valid (not expired)
  bool get isValid => DateTime.now().isBefore(expiresAt);

  /// Get remaining time in seconds
  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now());
    return diff.inSeconds > 0 ? diff.inSeconds : 0;
  }

  /// Check if offer is actionable (sent and not expired)
  bool get isActionable => status == 'sent' && isValid;

  @override
  String toString() => 'DispatchOffer(offerId: $offerId, orderId: $orderId, status: $status, round: $round)';
}
```

**Expected result:**
- File created at exact path
- No compilation errors
- Model follows Riverpod + Firestore best practices

**Verification command:**
```bash
flutter analyze apps/wawapp_driver
```

---

## 🔧 Prompt 2: Update Orders Service for v2.0

**Context:** The backend now requires `offerId` parameter for accepting orders. We need to update the orders service to use v2 Cloud Functions.

**Task:** Update the orders service to add v2 methods.

**File:** `apps/wawapp_driver/lib/features/orders/services/orders_service.dart`

**Changes needed:**

1. **Add these imports at the top:**
```dart
import '../models/dispatch_offer.dart';
```

2. **Add these new methods to the OrdersService class:**

```dart
/// Accept an offer (v2.0 - offer-based dispatch)
Future<void> acceptOfferV2({
  required String offerId,
  required String orderId,
}) async {
  try {
    final callable = _functions.httpsCallable('acceptOrderV2');
    final result = await callable.call({
      'orderId': orderId,
      'offerId': offerId,
    });

    if (result.data['success'] != true) {
      throw Exception(result.data['message'] ?? 'فشل قبول العرض');
    }
  } catch (e) {
    if (e.toString().contains('offer_expired')) {
      throw Exception('انتهت صلاحية العرض');
    } else if (e.toString().contains('already_accepted')) {
      throw Exception('تم قبول الطلب من قبل سائق آخر');
    } else if (e.toString().contains('driver_busy')) {
      throw Exception('لديك طلب نشط بالفعل');
    }
    rethrow;
  }
}

/// Reject an offer (v2.0)
Future<void> rejectOffer({required String offerId}) async {
  try {
    final callable = _functions.httpsCallable('rejectOffer');
    final result = await callable.call({'offerId': offerId});

    if (result.data['success'] != true) {
      throw Exception(result.data['message'] ?? 'فشل رفض العرض');
    }
  } catch (e) {
    rethrow;
  }
}

/// Watch dispatch offers for this driver (v2.0)
Stream<List<DispatchOffer>> watchMyOffers(String driverId) {
  return _firestore
      .collection('dispatch_offers')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'sent')
      .orderBy('sentAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => DispatchOffer.fromFirestore(doc))
          .where((offer) => offer.isValid) // Filter out expired offers
          .toList());
}
```

3. **Keep the old `acceptOrder` method for backward compatibility** (don't delete it yet)

**Expected result:**
- 3 new methods added to OrdersService
- Old methods preserved
- No compilation errors

**Verification command:**
```bash
flutter analyze apps/wawapp_driver
```

---

## 🎨 Prompt 3: Create Dispatch Offer Card Widget

**Context:** We need a new widget to display dispatch offers to drivers with countdown timer and accept/reject buttons.

**Task:** Create a new widget file.

**File:** `apps/wawapp_driver/lib/features/orders/widgets/dispatch_offer_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dispatch_offer.dart';
import '../providers/orders_provider.dart';
import 'dart:async';

/// Displays a dispatch offer with countdown timer
class DispatchOfferCard extends ConsumerStatefulWidget {
  final DispatchOffer offer;

  const DispatchOfferCard({
    Key? key,
    required this.offer,
  }) : super(key: key);

  @override
  ConsumerState<DispatchOfferCard> createState() => _DispatchOfferCardState();
}

class _DispatchOfferCardState extends ConsumerState<DispatchOfferCard> {
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.offer.remainingSeconds;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds = widget.offer.remainingSeconds;
          if (_remainingSeconds <= 0) {
            timer.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await ref.read(ordersProvider.notifier).acceptOfferV2(
            offerId: widget.offer.offerId,
            orderId: widget.offer.orderId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      await ref.read(ordersProvider.notifier).rejectOffer(
            offerId: widget.offer.offerId,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض العرض'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Color _getWaveColor() {
    switch (widget.offer.round) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpired = _remainingSeconds <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getWaveColor(),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Wave badge + Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Wave badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getWaveColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'الموجة ${widget.offer.round}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Countdown timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpired ? Colors.red : Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isExpired ? 'منتهي' : '$_remainingSeconds ث',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Distance
            Row(
              children: [
                Icon(Icons.location_on, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text(
                  '${widget.offer.distance.toStringAsFixed(1)} كم',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Priority
            Text(
              'الأولوية: ${widget.offer.priority}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            if (!isExpired && !_isProcessing)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _handleAccept,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('قبول'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _handleReject,
                      icon: const Icon(Icons.cancel),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (isExpired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'انتهت صلاحية العرض',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

**Expected result:**
- Widget file created
- No compilation errors
- Widget follows Material Design guidelines

**Verification command:**
```bash
flutter analyze apps/wawapp_driver
```

---

## 🔄 Prompt 4: Update Orders Provider

**Context:** We need to add the new v2 methods to the orders provider so the UI can call them.

**Task:** Add new methods to the existing OrdersProvider.

**File:** `apps/wawapp_driver/lib/features/orders/providers/orders_provider.dart`

**Changes needed:**

1. **Import the DispatchOffer model at the top:**
```dart
import '../models/dispatch_offer.dart';
```

2. **Add these methods to the OrdersProvider class (StateNotifier or AsyncNotifier):**

```dart
/// Accept an offer (v2.0)
Future<void> acceptOfferV2({
  required String offerId,
  required String orderId,
}) async {
  try {
    await _ordersService.acceptOfferV2(
      offerId: offerId,
      orderId: orderId,
    );

    // Refresh orders list
    await fetchOrders();
  } catch (e) {
    rethrow;
  }
}

/// Reject an offer (v2.0)
Future<void> rejectOffer({required String offerId}) async {
  try {
    await _ordersService.rejectOffer(offerId: offerId);
  } catch (e) {
    rethrow;
  }
}

/// Watch dispatch offers for current driver
Stream<List<DispatchOffer>> watchMyOffers(String driverId) {
  return _ordersService.watchMyOffers(driverId);
}
```

**Expected result:**
- 3 new methods added to provider
- Methods properly call service layer
- No compilation errors

**Verification command:**
```bash
flutter analyze apps/wawapp_driver
```

---

## ✅ Final Verification Checklist

After all 4 prompts are completed, verify:

- [ ] `flutter analyze apps/wawapp_driver` → No errors
- [ ] DispatchOffer model created with all fields
- [ ] OrdersService has acceptOfferV2, rejectOffer, watchMyOffers
- [ ] DispatchOfferCard widget created with timer
- [ ] OrdersProvider has v2 methods
- [ ] No compilation errors in entire driver app

---

## 🚀 Next Steps After Completion

1. Update `nearby_orders_screen.dart` to use `DispatchOfferCard`
2. Add StreamBuilder to listen to `watchMyOffers`
3. Test with real orders
4. Delete v1 methods after confirming v2 works

---

## 📞 Troubleshooting

**If Amazon Q makes errors:**
- Show it the error message
- Ask it to fix specifically
- Verify with `flutter analyze` after each fix

**Common issues:**
- Missing imports → Add manually
- Wrong file path → Create in correct location
- Type errors → Check Firestore field types match model

---

**Version:** 2.0.0
**Created:** 2026-04-16
**Author:** Claude Code + Amazon Q Collaboration
