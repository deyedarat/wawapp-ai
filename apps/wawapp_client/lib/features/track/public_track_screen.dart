import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:core_shared/core_shared.dart';
import 'providers/order_tracking_provider.dart';

import 'widgets/order_tracking_view.dart';

class PublicTrackScreen extends ConsumerWidget {
  final String orderId;

  const PublicTrackScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final orderSnapshot = ref.watch(orderTrackingProvider(orderId));

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(kReleaseMode ? 'تتبع الطلب' : 'تتبع الطلب • DEBUG'),
        ),
        body: SafeArea(
          child: orderSnapshot.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 80,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'لا يمكن عرض هذا الطلب',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'تحقق من رابط التتبع أو حاول لاحقًا',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            ),
            data: (snapshot) {
              if (snapshot == null || !snapshot.exists) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'الطلب غير موجود',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'تحقق من رابط التتبع أو حاول لاحقًا',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('العودة'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data() as Map<String, dynamic>;
              final order = Order(
                distanceKm: (data['distanceKm'] as num).toDouble(),
                price: (data['price'] as num).toDouble(),
                pickupAddress:
                    (data['pickup'] as Map<String, dynamic>)['label'] as String,
                dropoffAddress: (data['dropoff']
                    as Map<String, dynamic>)['label'] as String,
                pickup: LocationPoint(
                  lat:
                      (data['pickup'] as Map<String, dynamic>)['lat'] as double,
                  lng:
                      (data['pickup'] as Map<String, dynamic>)['lng'] as double,
                  label: (data['pickup'] as Map<String, dynamic>)['label']
                      as String,
                ),
                dropoff: LocationPoint(
                  lat: (data['dropoff'] as Map<String, dynamic>)['lat']
                      as double,
                  lng: (data['dropoff'] as Map<String, dynamic>)['lng']
                      as double,
                  label: (data['dropoff'] as Map<String, dynamic>)['label']
                      as String,
                ),
                status: data['status'] as String?,
                driverId: data['driverId'] as String?,
              );

              return OrderTrackingView(
                order: order,
                readOnly: true,
              );
            },
          ),
        ),
      ),
    );
  }
}
