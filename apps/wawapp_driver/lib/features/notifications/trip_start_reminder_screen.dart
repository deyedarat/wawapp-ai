import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/orders_service.dart';

/// Data class for trip start reminder notification payload.
class TripStartReminderData {
  const TripStartReminderData({
    required this.orderId,
    required this.pickupLabel,
    required this.destinationLabel,
    required this.elapsedMinutes,
    this.createdAtMs,
  });

  final String orderId;
  final String pickupLabel;
  final String destinationLabel;
  final int elapsedMinutes;
  final int? createdAtMs;

  /// Parse from FCM notification data map with validation.
  static TripStartReminderData? tryParse(Map<String, dynamic>? data) {
    if (data == null) return null;
    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return null;

    return TripStartReminderData(
      orderId: orderId,
      pickupLabel: (data['pickupLabel'] as String?) ?? 'موقع الاستلام',
      destinationLabel: (data['destinationLabel'] as String?) ?? 'الوجهة',
      elapsedMinutes: _toInt(data['elapsedMinutes']) ?? 0,
      createdAtMs: _toInt(data['createdAt']),
    );
  }

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

/// Full-screen reminder for driver to start the trip after accepting order.
/// Appears with urgent styling (amber background) and countdown timer.
class TripStartReminderScreen extends ConsumerStatefulWidget {
  const TripStartReminderScreen({super.key, required this.data});

  final TripStartReminderData data;

  @override
  ConsumerState<TripStartReminderScreen> createState() =>
      _TripStartReminderScreenState();
}

class _TripStartReminderScreenState
    extends ConsumerState<TripStartReminderScreen> {
  bool _isLoading = false;
  Timer? _countdownTimer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Calculate elapsed from acceptedAt if available, otherwise use elapsedMinutes from FCM
    if (widget.data.createdAtMs != null && widget.data.createdAtMs! > 0) {
      // createdAt in the reminder payload is the current time when reminder was sent
      // Use elapsedMinutes from FCM as the base (time since acceptance)
      _elapsedSeconds = widget.data.elapsedMinutes * 60;
    } else {
      _elapsedSeconds = widget.data.elapsedMinutes * 60;
    }
    // If still 0, try to calculate from order's acceptedAt via Firestore
    if (_elapsedSeconds == 0) {
      _fetchAcceptedAt();
    }
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        setState(() => _elapsedSeconds++);
      },
    );
  }

  Future<void> _fetchAcceptedAt() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.data.orderId)
          .get();
      final acceptedAt = doc.data()?['acceptedAt'];
      if (acceptedAt != null && acceptedAt is Timestamp) {
        final elapsed = DateTime.now().difference(acceptedAt.toDate());
        if (mounted) {
          setState(() {
            _elapsedSeconds = elapsed.inSeconds;
          });
        }
      }
    } catch (_) {
      // Non-fatal — keep counting from 0
    }
  }

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _dismissNotification() {
    FlutterLocalNotificationsPlugin().cancel(widget.data.orderId.hashCode);
  }

  Future<void> _startTrip() async {
    _dismissNotification();
    setState(() => _isLoading = true);
    try {
      // Transition order from 'accepted' to 'on_route' (trip started)
      await ref.read(ordersServiceProvider).transition(
            widget.data.orderId,
            OrderStatus.onRoute,
          );
      if (!mounted) return;
      context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('not found')
                ? 'لم يتم العثور على الطلب'
                : 'حدث خطأ، حاول مرة أخرى',
          ),
          backgroundColor: const Color(0xFFE53935),
        ),
      );
    }
  }

  void _dismiss() {
    _dismissNotification();
    if (!mounted) return;
    context.go('/active-order');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF59E0B), // Amber warning color
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Warning icon with countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'هل وصلت للعميل؟',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'حان وقت بدء الرحلة',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // Countdown timer card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Countdown display
                    Text(
                      _formattedTime,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF59E0B),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الوقت منذ القبول',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Pickup location
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 24,
                          color: Color(0xFF1B5E20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.data.pickupLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Destination location
                    Row(
                      children: [
                        const Icon(
                          Icons.flag,
                          size: 24,
                          color: Color(0xFFE53935),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.data.destinationLabel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              // Action buttons
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 48),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Start trip button (primary)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _startTrip,
                          icon: const Icon(Icons.play_arrow, size: 28),
                          label: const Text(
                            'وصلت للعميل',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Not yet button (secondary)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: TextButton.icon(
                          onPressed: _dismiss,
                          icon: const Icon(Icons.close, size: 22),
                          label: const Text(
                            'لم أصل بعد',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
