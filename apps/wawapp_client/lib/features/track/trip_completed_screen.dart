import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';
import 'package:core_shared/core_shared.dart';
import 'data/orders_repository.dart';

import 'providers/order_tracking_provider.dart';
import '../../widgets/error_screen.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';

class TripCompletedScreen extends ConsumerStatefulWidget {
  final String orderId;

  const TripCompletedScreen({super.key, required this.orderId});

  @override
  ConsumerState<TripCompletedScreen> createState() =>
      _TripCompletedScreenState();
}

class _TripCompletedScreenState extends ConsumerState<TripCompletedScreen> {
  int? _selectedRating;
  bool _isSubmitting = false;
  bool _hasLoggedView = false;

  @override
  void initState() {
    super.initState();
    // Log trip completed view once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasLoggedView) {
        _hasLoggedView = true;
        AnalyticsService.instance
            .logTripCompletedViewed(orderId: widget.orderId);
      }
    });
  }

  Future<void> _submitRating() async {
    if (_selectedRating == null) return;

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(ordersRepositoryProvider);
      await repository.rateDriver(
        orderId: widget.orderId,
        rating: _selectedRating!,
      );

      // Check if user arrived via notification
      final notificationSource = FCMService.instance.getNotificationSource(widget.orderId);
      if (notificationSource == 'trip_completed') {
        // Track conversion: notification → rating
        AnalyticsService.instance.logDriverRatedFromNotification(
          orderId: widget.orderId,
          rating: _selectedRating!,
        );
      }

      // Log analytics event
      AnalyticsService.instance.logDriverRated(
        orderId: widget.orderId,
        rating: _selectedRating!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('شكرًا لتقييمك!')),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّر إرسال التقييم، حاول مرة أخرى.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderTrackingProvider(widget.orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('اكتمل الطلب')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final appError = AppError.from(error);
          return ErrorScreen(
            message: appError.toUserMessage(),
            onRetry: () => ref.refresh(orderTrackingProvider(widget.orderId)),
          );
        },
        data: (snapshot) {
          final data = snapshot?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final order =
              Order.fromFirestore({...data, 'id': widget.orderId});
          final completedAt = data['completedAt'] as Timestamp?;
          final dateStr = completedAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(completedAt.toDate())
              : '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'تم إكمال الرحلة بنجاح',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('من: ${order.pickupAddress}'),
                        const SizedBox(height: 8),
                        Text('إلى: ${order.dropoffAddress}'),
                        const SizedBox(height: 8),
                        Text(
                            'المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
                        const SizedBox(height: 8),
                        Text('السعر: ${order.price} MRU'),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('التاريخ: $dateStr'),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'قيّم السائق',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _selectedRating = rating),
                      icon: Icon(
                        rating <= (_selectedRating ?? 0)
                            ? Icons.star
                            : Icons.star_border,
                        size: 40,
                        color: rating <= (_selectedRating ?? 0)
                            ? Colors.amber
                            : Colors.grey,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _selectedRating != null && !_isSubmitting
                      ? _submitRating
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('إرسال التقييم'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
