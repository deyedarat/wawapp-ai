import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import '../../services/orders_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/error_screen.dart';
import 'providers/active_order_provider.dart';
import '../auth/providers/auth_service_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import 'dart:developer' as dev;

class ActiveOrderScreen extends ConsumerStatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  ConsumerState<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends ConsumerState<ActiveOrderScreen> {
  bool _isTrackingStarted = false;
  bool _isCancelling = false;

  @override
  void dispose() {
    if (_isTrackingStarted) {
      TrackingService.instance.stopTracking();
    }
    super.dispose();
  }

  Future<void> _transition(String orderId, OrderStatus to) async {
    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.transition(orderId, to);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث حالة الطلب')),
      );
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: ${e.toString()}')),
      );
    }
  }

  Future<void> _showCancelDialog(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل تريد إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: DriverAppColors.accentRed),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cancelOrder(orderId);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    setState(() => _isCancelling = true);

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.cancelOrder(orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الطلب بواسطة السائق')),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null) {
      if (kDebugMode) {
        dev.log('[Matching] ActiveOrderScreen: User not authenticated');
      }
      return const Scaffold(
        body: Center(child: Text('غير مسجل الدخول')),
      );
    }

    if (kDebugMode) {
      dev.log(
          '[Matching] ActiveOrderScreen: Building screen for driver ${user.uid}');
    }

    final ordersAsync = ref.watch(activeOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الطلب النشط')),
      body: ordersAsync.when(
        loading: () {
          if (kDebugMode) {
            dev.log('[Matching] ActiveOrderScreen: Waiting for stream data');
          }
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stack) {
          if (kDebugMode) {
            dev.log('[Matching] ActiveOrderScreen: Stream error: $error');
          }
          final appError = AppError.from(error);
          return ErrorScreen(
            message: appError.toUserMessage(),
            onRetry: () => ref.refresh(activeOrdersProvider),
          );
        },
        data: (orders) {
          if (kDebugMode) {
            dev.log(
                '[Matching] ActiveOrderScreen: Received ${orders.length} active orders');
          }

          // Handle tracking based on active orders
          if (orders.isNotEmpty && !_isTrackingStarted) {
            _isTrackingStarted = true;
            TrackingService.instance.startTracking();
          } else if (orders.isEmpty && _isTrackingStarted) {
            _isTrackingStarted = false;
            TrackingService.instance.stopTracking();
          }

          if (orders.isEmpty) {
            return const DriverEmptyState(
              icon: Icons.inbox,
              message: 'لا توجد طلبات نشطة',
            );
          }

          final order = orders.first;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'طلب #${order.id != null && order.id!.length > 6 ? order.id!.substring(order.id!.length - 6) : order.id ?? 'N/A'}',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('من: ${order.pickup.label}'),
                        Text('إلى: ${order.dropoff.label}'),
                        Text(
                            'المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
                        Text('السعر: ${order.price} MRU'),
                        Text('الحالة: ${order.orderStatus.toArabicLabel()}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed:
                      order.orderStatus.canDriverStartTrip && order.id != null
                          ? () => _transition(order.id!, OrderStatus.onRoute)
                          : null,
                  child: const Text('بدء الرحلة'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: order.orderStatus.canDriverCompleteTrip &&
                          order.id != null
                      ? () => _transition(order.id!, OrderStatus.completed)
                      : null,
                  child: const Text('إكمال الطلب'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: order.orderStatus.canDriverCancel &&
                          !_isCancelling &&
                          order.id != null
                      ? () => _showCancelDialog(order.id!)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DriverAppColors.accentRed,
                    side: const BorderSide(color: DriverAppColors.accentRed),
                  ),
                  child: _isCancelling
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إلغاء الطلب'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
