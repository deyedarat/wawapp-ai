import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/notification_method_channel.dart';
import '../../services/notification_service.dart';
import '../../services/orders_service.dart';
import 'widgets/order_details_card.dart';

/// Data class for notification payload passed via GoRouter extra.
class FullScreenNotificationData {
  const FullScreenNotificationData({
    required this.orderId,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.price,
    required this.distance,
    this.createdAtMs,
    this.offerId,
  });

  final String orderId;
  final String pickupLabel;
  final String dropoffLabel;
  final double price;
  final double distance;
  final int? createdAtMs;
  final String? offerId;

  /// Parse from FCM notification data map with validation.
  static FullScreenNotificationData? tryParse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return null;

    return FullScreenNotificationData(
      orderId: orderId,
      pickupLabel: (data['pickupLabel'] as String?) ?? 'موقع الاستلام',
      dropoffLabel: (data['dropoffLabel'] as String?) ?? 'موقع التوصيل',
      price: _toDouble(data['price']),
      distance: _toDouble(data['distance']),
      createdAtMs: _toInt(data['createdAt']),
      offerId: data['offerId'] as String?,
    );
  }

  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class FullScreenNotificationScreen extends ConsumerStatefulWidget {
  const FullScreenNotificationScreen({super.key, required this.data});

  final FullScreenNotificationData data;

  @override
  ConsumerState<FullScreenNotificationScreen> createState() =>
      _FullScreenNotificationScreenState();
}

class _FullScreenNotificationScreenState
    extends ConsumerState<FullScreenNotificationScreen> {
  bool _isLoading = false;
  bool _actionTaken = false; // Prevents zombie re-interaction after any action
  int _failCount = 0;
  Timer? _elapsedTimer;
  Timer? _maxLifetimeTimer;
  String _elapsedText = '';
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  StreamSubscription<DocumentSnapshot>? _offerSubscription;

  static const _terminalStatuses = {
    'cancelledByClient',
    'cancelledByDriver',
    'expired',
    'completed',
    'accepted',
  };
  static const _maxLifetime = Duration(minutes: 5);
  static const _maxRetries = 2;

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateElapsed(),
    );
    // Backend truth reconciliation: auto-dismiss if order becomes non-actionable
    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.data.orderId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final status = snap.data()?['status'] as String?;
      if (!snap.exists || (status != null && _terminalStatuses.contains(status))) {
        _safeDismiss();
      }
    });
    // Also monitor the specific dispatch_offer — dismiss if offer expires/cancelled
    // even when order stays 'matching' (another wave being tried)
    final offerId = widget.data.offerId;
    if (offerId != null && offerId.isNotEmpty) {
      _offerSubscription = FirebaseFirestore.instance
          .collection('dispatch_offers')
          .doc(offerId)
          .snapshots()
          .listen((snap) {
        if (!mounted || _actionTaken) return;
        final status = snap.data()?['status'] as String?;
        const offerTerminal = {'expired', 'cancelled', 'accepted', 'rejected'};
        if (!snap.exists || (status != null && offerTerminal.contains(status))) {
          _safeDismiss();
        }
      });
    }
    // Timeout protection: fullscreen cannot survive indefinitely
    _maxLifetimeTimer = Timer(_maxLifetime, () {
      if (mounted && !_actionTaken) _safeDismiss();
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _maxLifetimeTimer?.cancel();
    _orderSubscription?.cancel();
    _offerSubscription?.cancel();
    NotificationService().clearActiveFullScreen();
    super.dispose();
  }

  /// Safe dismiss: cleans up notification state and navigates away.
  void _safeDismiss() {
    if (!mounted) return;
    _actionTaken = true;
    _dismissNotification();
    NotificationService().clearActiveFullScreen();
    context.go('/nearby');
  }

  void _updateElapsed() {
    final ms = widget.data.createdAtMs;
    if (ms == null || ms <= 0) {
      setState(() => _elapsedText = '—');
      return;
    }
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
    setState(() {
      if (diff.inHours > 0) {
        _elapsedText = '${diff.inHours} س';
      } else if (diff.inMinutes > 0) {
        _elapsedText = '${diff.inMinutes} د';
      } else {
        _elapsedText = 'الآن';
      }
    });
  }

  void _dismissNotification() {
    FlutterLocalNotificationsPlugin().cancel(widget.data.orderId.hashCode);
    NotificationMethodChannel.cancelOrderNotification(widget.data.orderId);
  }

  Future<void> _accept() async {
    if (_actionTaken || _isLoading) return; // Debounce + zombie guard
    _actionTaken = true;
    _dismissNotification();
    NotificationService().clearActiveFullScreen();
    NotificationMethodChannel.cancelSnooze(widget.data.orderId);
    setState(() => _isLoading = true);
    try {
      final offerId = widget.data.offerId;
      if (offerId == null || offerId.isEmpty) {
        if (!mounted) return;
        _safeDismiss();
        return;
      }
      await ref.read(ordersServiceProvider).acceptOfferV2(
        offerId: offerId,
        orderId: widget.data.orderId,
      );
      NotificationService().markOrderAsProcessed(widget.data.orderId);
      if (!mounted) return;
      context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      _failCount++;

      // EC1: Before showing error, check if acceptance actually succeeded server-side
      // (response was lost due to timeout/network)
      final reconciledOrderId = await OrdersService.reconcileActiveOrder();
      if (reconciledOrderId != null) {
        // Success! Server accepted the order, response was just lost.
        NotificationService().markOrderAsProcessed(widget.data.orderId);
        if (!mounted) return;
        context.go('/active-order');
        return;
      }

      final isFatal = e.toString().contains('already taken') ||
          e.toString().contains('offer_expired') ||
          e.toString().contains('already_accepted') ||
          _failCount > _maxRetries;
      if (isFatal) {
        // Non-recoverable: dismiss immediately
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('already taken') || e.toString().contains('already_accepted')
                  ? 'تم أخذ الطلب بالفعل'
                  : 'انتهت صلاحية العرض',
            ),
          ),
        );
        _safeDismiss();
      } else {
        // Recoverable: allow one more retry
        _actionTaken = false;
        setState(() => _isLoading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ، حاول مرة أخرى')),
        );
      }
    }
  }

  Future<void> _reject() async {
    _dismissNotification();
    NotificationService().markOrderAsProcessed(widget.data.orderId);
    NotificationService().clearActiveFullScreen();
    NotificationMethodChannel.cancelSnooze(widget.data.orderId);
    setState(() => _isLoading = true);

    final offerId = widget.data.offerId;

    // Call rejectOffer Cloud Function to release the offer for other drivers
    if (offerId != null && offerId.isNotEmpty) {
      try {
        await ref.read(ordersServiceProvider).rejectOffer(offerId: offerId);
        if (kDebugMode) {
          debugPrint('[FullScreenNotif] Offer $offerId rejected via Cloud Function');
        }
      } on Object catch (e) {
        if (kDebugMode) {
          debugPrint('[FullScreenNotif] rejectOffer CF failed (non-blocking): $e');
        }
      }
    }

    // Also persist locally for native dedup (prevents re-showing same offer)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('driver_rejected_orders')
            .add({
          'driverId': uid,
          'orderId': widget.data.orderId,
          'rejectedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(hours: 24)),
          ),
        });
      } on Object catch (e) {
        if (kDebugMode) {
          debugPrint('[FullScreenNotif] Failed to write local rejection: $e');
        }
      }
    }

    // Mark as rejected in native SharedPreferences (prevents FCM re-delivery)
    await NotificationMethodChannel.addRejectedOrderId(widget.data.orderId);

    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go('/');
  }

  void _snooze() {
    _dismissNotification();
    NotificationService().clearActiveFullScreen();
    // Clear dedup for this offer so the snooze alarm can re-show it.
    final offerKey = widget.data.offerId ?? widget.data.orderId;
    NotificationService().clearSnoozedOffer(offerKey);
    // Schedule via Android AlarmManager (survives Doze + process death)
    NotificationMethodChannel.scheduleSnooze(
      orderId: widget.data.orderId,
      offerId: widget.data.offerId ?? '',
      delaySeconds: 300,
      pickupLabel: widget.data.pickupLabel,
      dropoffLabel: widget.data.dropoffLabel,
      price: widget.data.price,
      distance: widget.data.distance,
      createdAt: widget.data.createdAtMs ?? 0,
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _safeDismiss();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF1B5E20),
          body: SafeArea(
            child: Column(
              children: [
              const Spacer(flex: 2),
              // Header
              const Icon(
                Icons.local_shipping_rounded,
                size: 72,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'طلب جديد قريب منك',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // Order details card
              OrderDetailsCard(
                pickupLabel: widget.data.pickupLabel,
                dropoffLabel: widget.data.dropoffLabel,
                price: widget.data.price,
                distance: widget.data.distance,
                elapsedText: _elapsedText,
              ),
              const Spacer(flex: 3),
              // Action buttons
              if (_isLoading || _actionTaken)
                const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Accept button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _accept,
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: const Text(
                            'قبول الطلب',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1B5E20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Reject + Snooze row
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _reject,
                                icon: const Icon(Icons.close, size: 22),
                                label: const Text('رفض',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _snooze,
                                icon: const Icon(Icons.schedule, size: 22),
                                label: const Text('لاحقاً',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
