import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/orders_service.dart';
import 'providers/snooze_provider.dart';
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
  });

  final String orderId;
  final String pickupLabel;
  final String dropoffLabel;
  final double price;
  final double distance;
  final int? createdAtMs;

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
  Timer? _elapsedTimer;
  String _elapsedText = '';

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    _elapsedTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateElapsed(),
    );
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
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

  Future<void> _accept() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(ordersServiceProvider).acceptOrder(widget.data.orderId);
      if (!mounted) return;
      context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('already taken')
                ? 'تم أخذ الطلب بالفعل'
                : 'حدث خطأ، حاول مرة أخرى',
          ),
        ),
      );
    }
  }

  void _reject() {
    context.go('/nearby');
  }

  void _snooze() {
    ref.read(snoozeProvider.notifier).scheduleReminder(
          widget.data.orderId,
          () {
            // Callback will be handled by notification service
          },
        );
    context.go('/nearby');
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
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
              if (_isLoading)
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
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                              child: OutlinedButton.icon(
                                onPressed: _reject,
                                icon: const Icon(Icons.close, size: 22),
                                label: const Text('رفض', style: TextStyle(fontSize: 16)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
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
                              child: OutlinedButton.icon(
                                onPressed: _snooze,
                                icon: const Icon(Icons.schedule, size: 22),
                                label: const Text('لاحقاً', style: TextStyle(fontSize: 16)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(color: Colors.white30),
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
    );
  }
}
