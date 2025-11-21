import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:core_shared/core_shared.dart';
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'providers/quote_provider.dart';
import '../map/pick_route_controller.dart';
import '../track/models/order.dart';
import '../track/data/orders_repository.dart';
import '../../core/utils/address_utils.dart';
import '../../core/utils/eta.dart';
import '../../core/pricing/pricing.dart';
import '../../services/analytics_service.dart';

class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key});

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  void _startOrderTracking(String orderId) {
    final repo = ref.read(ordersRepositoryProvider);
    repo.watchOrder(orderId).listen((snapshot) {
      if (!mounted) return;

      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'accepted') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/driver-found/$orderId');
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final quoteState = ref.watch(quoteProvider);

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title:
              Text(kReleaseMode ? l10n.get_quote : '${l10n.get_quote} • DEBUG'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.local_shipping, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              Text(
                l10n.estimated_price,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final breakdown = quoteState.distanceKm != null
                      ? Pricing.compute(quoteState.distanceKm!)
                      : null;
                  final price = breakdown?.rounded ?? 0;
                  return Column(
                    children: [
                      Text(
                        price > 0
                            ? '${l10n.currency} ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}'
                            : '--- ${l10n.currency}',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      if (breakdown != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'تفصيل السعر: أساس ${breakdown.base} + مسافة ${breakdown.distancePart} = ${breakdown.total} → حد أدنى ${PricingConfig.minFare} → تقريب $price',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (quoteState.distanceKm != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${quoteState.distanceKm!.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'الوقت التقريبي: ${Eta.minutesFromKm(quoteState.distanceKm!).ceil()} دقيقة',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: quoteState.isReady
                    ? () async {
                        try {
                          final repo = ref.read(ordersRepositoryProvider);
                          final routeState = ref.read(routePickerProvider);
                          final fromText = AddressUtils.friendly(
                            userInput: routeState.pickupAddress,
                            latLng: routeState.pickup,
                          );
                          final toText = AddressUtils.friendly(
                            userInput: routeState.dropoffAddress,
                            latLng: routeState.dropoff,
                          );
                          final breakdown =
                              Pricing.compute(quoteState.distanceKm!);

                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) {
                            throw Exception('User not authenticated');
                          }

                          final orderId = await repo.createOrder(
                            ownerId: user.uid,
                            pickup: {
                              'lat': routeState.pickup!.latitude,
                              'lng': routeState.pickup!.longitude,
                            },
                            dropoff: {
                              'lat': routeState.dropoff!.latitude,
                              'lng': routeState.dropoff!.longitude,
                            },
                            pickupAddress: fromText,
                            dropoffAddress: toText,
                            distanceKm: quoteState.distanceKm!,
                            price: breakdown.rounded,
                          );

                          // Log analytics event
                          AnalyticsService.instance.logOrderCreated(
                            orderId: orderId,
                            priceAmount: breakdown.rounded,
                            distanceKm: quoteState.distanceKm!,
                          );

                          if (!mounted) return;
                          final order = Order(
                            distanceKm: quoteState.distanceKm!,
                            price: breakdown.rounded.toDouble(),
                            pickupAddress: fromText,
                            dropoffAddress: toText,
                            pickup: routeState.pickup!,
                            dropoff: routeState.dropoff!,
                            status: OrderStatus.assigning.toFirestore(),
                          );

                          _startOrderTracking(orderId);
                          if (!mounted) return;
                          context.push('/track', extra: order);
                        } catch (e, stackTrace) {
                          // Debug logging for future diagnostics
                          debugPrint(
                              '[OrdersClient] Failed to create order: $e');
                          debugPrint('[OrdersClient] Stack trace: $stackTrace');

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'حدث خطأ أثناء إنشاء الطلب. يرجى المحاولة مرة أخرى.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    : null,
                child: Text(l10n.request_now),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
