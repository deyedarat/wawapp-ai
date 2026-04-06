import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../services/orders_service.dart';
import '../active/widgets/cancel_order_dialog.dart';

/// Shows the trip-start reminder dialog as an overlay.
/// Auto-dismisses when order status changes away from 'accepted'.
Future<void> showTripStartReminderDialog(
  BuildContext context, {
  required String orderId,
  required String pickupLabel,
  required String dropoffLabel,
  required int totalTimeoutMs,
  required int acceptedAtMs,
  int extensionRequestCount = 0,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _TripStartReminderDialog(
      orderId: orderId,
      pickupLabel: pickupLabel,
      dropoffLabel: dropoffLabel,
      totalTimeoutMs: totalTimeoutMs,
      acceptedAtMs: acceptedAtMs,
      extensionRequestCount: extensionRequestCount,
    ),
  );
}

class _TripStartReminderDialog extends ConsumerStatefulWidget {
  const _TripStartReminderDialog({
    required this.orderId,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.totalTimeoutMs,
    required this.acceptedAtMs,
    required this.extensionRequestCount,
  });

  final String orderId;
  final String pickupLabel;
  final String dropoffLabel;
  final int totalTimeoutMs;
  final int acceptedAtMs;
  final int extensionRequestCount;

  @override
  ConsumerState<_TripStartReminderDialog> createState() =>
      _TripStartReminderDialogState();
}

class _TripStartReminderDialogState
    extends ConsumerState<_TripStartReminderDialog> {
  Timer? _ticker;
  int _remainingSeconds = 0;
  bool _isExtending = false;
  bool _isStarting = false;
  int _extensionCount = 0;
  int _totalTimeoutMs = 0;

  @override
  void initState() {
    super.initState();
    _extensionCount = widget.extensionRequestCount;
    _totalTimeoutMs = widget.totalTimeoutMs;
    _updateRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final deadlineMs = widget.acceptedAtMs + _totalTimeoutMs;
    final remaining = ((deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (!mounted) return;
    setState(() => _remainingSeconds = remaining.clamp(0, 99999));

    // Auto-dismiss if expired
    if (remaining <= 0 && mounted) {
      Navigator.of(context).pop();
    }
  }

  String get _remainingText {
    if (_remainingSeconds <= 0) return 'انتهى الوقت';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    if (m > 0) return '$m:${s.toString().padLeft(2, '0')}';
    return '$s ثانية';
  }

  double get _progress {
    final totalSeconds = _totalTimeoutMs / 1000;
    if (totalSeconds <= 0) return 0;
    return (_remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  bool get _isUrgent => _remainingSeconds < 60;
  bool get _canExtend => _extensionCount < 1;

  Future<void> _startTrip() async {
    setState(() => _isStarting = true);
    try {
      await ref.read(ordersServiceProvider).transition(widget.orderId, OrderStatus.onRoute);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e is AppError ? e.toUserMessage() : e.toString()}')),
      );
    }
  }

  Future<void> _requestExtension() async {
    setState(() => _isExtending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestTripStartExtension');
      final result = await callable.call({'orderId': widget.orderId});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] == true) {
        final extraMs = ((data['extensionGrantedMinutes'] as num?) ?? 2) * 60000;
        if (mounted) {
          setState(() {
            _extensionCount++;
            _totalTimeoutMs += extraMs.toInt();
            _isExtending = false;
          });
          _updateRemaining();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم منحك دقيقتين إضافيتين')),
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _isExtending = false);
      final msg = e.code == 'resource-exhausted'
          ? 'لقد استخدمت التمديد بالفعل'
          : 'تعذر طلب التمديد';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _isExtending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ في الاتصال، حاول مرة أخرى')),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final reason = await showCancelOrderDialog(context);

    if (reason == null || !mounted) return;

    try {
      await ref.read(ordersServiceProvider).cancelOrder(widget.orderId, reason: reason);
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/nearby');
      }
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e is AppError ? e.toUserMessage() : e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final urgentColor = _isUrgent ? DriverAppColors.accentRed : DriverAppColors.primaryLight;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Material(
          color: Colors.transparent,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Countdown ──
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(urgentColor),
                        ),
                      ),
                      Text(
                        _remainingText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: urgentColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Title ──
                const Text(
                  'هل وصلت للعميل؟',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _isUrgent ? 'الوقت ينفد!' : 'ابدأ الرحلة قبل انتهاء المهلة',
                  style: TextStyle(fontSize: 14, color: _isUrgent ? DriverAppColors.accentRed : Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // ── Order summary ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _locationRow(Icons.circle, DriverAppColors.primaryLight, widget.pickupLabel),
                      const SizedBox(height: 8),
                      _locationRow(Icons.location_on, DriverAppColors.accentRed, widget.dropoffLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Start trip button ──
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isStarting ? null : _startTrip,
                    icon: _isStarting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('بدء الرحلة الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DriverAppColors.primaryLight,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Extension button ──
                if (_canExtend)
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isExtending ? null : _requestExtension,
                      icon: _isExtending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.schedule, size: 20),
                      label: const Text('طلب وقت إضافي (+2 دقائق)', style: TextStyle(fontSize: 14)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DriverAppColors.secondaryLight,
                        side: const BorderSide(color: DriverAppColors.secondaryLight),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),

                // ── Cancel button ──
                TextButton(
                  onPressed: _cancelOrder,
                  style: TextButton.styleFrom(foregroundColor: DriverAppColors.accentRed),
                  child: const Text('إلغاء الطلب', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, Color color, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        ),
      ],
    );
  }
}
