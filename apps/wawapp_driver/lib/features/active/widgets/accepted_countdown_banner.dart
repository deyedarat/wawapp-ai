import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../providers/accepted_order_meta_provider.dart';

/// Top banner showing countdown timer + extension button for accepted orders.
/// Auto-hides when order transitions away from 'accepted'.
class AcceptedCountdownBanner extends ConsumerStatefulWidget {
  const AcceptedCountdownBanner({super.key});

  @override
  ConsumerState<AcceptedCountdownBanner> createState() =>
      _AcceptedCountdownBannerState();
}

class _AcceptedCountdownBannerState
    extends ConsumerState<AcceptedCountdownBanner> {
  Timer? _ticker;
  int _remainingSeconds = 0;
  bool _isExtending = false;
  // Local override after extension granted (before Firestore catches up)
  int? _localExtraMs;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker(AcceptedOrderMeta meta) {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _recalculate(meta);
    });
    _recalculate(meta);
  }

  void _recalculate(AcceptedOrderMeta meta) {
    final totalMs = meta.totalTimeoutMs + (_localExtraMs ?? 0);
    final deadlineMs = meta.acceptedAtMs + totalMs;
    final remaining =
        ((deadlineMs - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
    if (!mounted) return;
    setState(() => _remainingSeconds = remaining.clamp(0, 99999));
  }

  Color get _bannerColor {
    if (_remainingSeconds < 60) return DriverAppColors.accentRed;
    if (_remainingSeconds < 120) return DriverAppColors.warningLight;
    return DriverAppColors.primaryLight;
  }

  String get _timerText {
    if (_remainingSeconds <= 0) return '00:00';
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _requestExtension(String orderId) async {
    setState(() => _isExtending = true);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestTripStartExtension');
      final result = await callable.call({'orderId': orderId});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] == true && mounted) {
        final extraMs =
            ((data['extensionGrantedMinutes'] as num?) ?? 2) * 60000;
        setState(() {
          _localExtraMs = (_localExtraMs ?? 0) + extraMs.toInt();
          _isExtending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم منحك دقيقتين إضافيتين')),
        );
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
        const SnackBar(content: Text('خطأ في الاتصال')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(acceptedOrderMetaProvider);

    return metaAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meta) {
        if (meta == null) {
          _ticker?.cancel();
          return const SizedBox.shrink();
        }

        // Start/restart ticker when meta changes
        _startTicker(meta);

        final canExtend = meta.extensionRequestCount < 1 &&
            _localExtraMs == null &&
            _remainingSeconds > 0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: _bannerColor,
          child: Row(
            children: [
              // Timer
              Icon(
                _remainingSeconds < 60 ? Icons.warning_rounded : Icons.timer,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'ابدأ الرحلة: $_timerText',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              // Extension button
              if (canExtend)
                SizedBox(
                  height: 32,
                  child: OutlinedButton(
                    onPressed: _isExtending
                        ? null
                        : () => _requestExtension(meta.orderId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isExtending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('+2 د', style: TextStyle(fontSize: 13)),
                  ),
                ),
              if (!canExtend && meta.extensionRequestCount >= 1)
                const Text(
                  'مستخدم',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
