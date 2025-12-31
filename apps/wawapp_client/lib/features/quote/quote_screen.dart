import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart' hide Order;
import 'package:core_shared/src/order.dart' as core;
import '../../l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'providers/quote_provider.dart';
import '../map/pick_route_controller.dart';
import '../auth/providers/auth_service_provider.dart';

import '../track/data/orders_repository.dart';
import '../../core/utils/address_utils.dart';
import '../../core/utils/eta.dart';
import '../../core/pricing/pricing.dart';
import '../../services/analytics_service.dart';
import '../shipment_type/shipment_type_provider.dart';
import '../../core/models/shipment_type.dart';
import '../../core/pricing/shipment_pricing.dart';

// NEW THEME IMPORTS
import '../../theme/colors.dart';
import '../../theme/components.dart';
import '../../theme/theme_extensions.dart';

class QuoteScreen extends ConsumerStatefulWidget {
  const QuoteScreen({super.key});

  @override
  ConsumerState<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends ConsumerState<QuoteScreen> {
  StreamSubscription<DocumentSnapshot>? _orderSubscription;

  void _startOrderTracking(String orderId) {
    _orderSubscription?.cancel();
    final repo = ref.read(ordersRepositoryProvider);
    _orderSubscription = repo.watchOrder(orderId).listen((snapshot) {
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
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final quoteState = ref.watch(quoteProvider);
    final theme = Theme.of(context);

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(kReleaseMode
              ? l10n.estimated_price
              : '${l10n.estimated_price} • DEBUG'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon Header
                Icon(
                  Icons.local_shipping_outlined,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: WawAppSpacing.lg),

                // Title
                Text(
                  l10n.estimated_price,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: WawAppSpacing.md),

                // Price Card
                WawCard(
                  elevation: WawAppElevation.medium,
                  child: Builder(
                    builder: (context) {
                      // Get selected shipment type
                      final shipmentType =
                          ref.watch(selectedShipmentTypeProvider);

                      final breakdown = quoteState.distanceKm != null
                          ? Pricing.computeWithShipmentType(
                              quoteState.distanceKm!,
                              shipmentType,
                            )
                          : null;
                      final price = breakdown?.rounded ?? 0;
                      return Column(
                        children: [
                          // Price Display
                          Text(
                            price > 0
                                ? '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ${l10n.currency}'
                                : '--- ${l10n.currency}',
                            style: theme.textTheme.displayLarge?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          if (breakdown != null) ...[
                            SizedBox(height: WawAppSpacing.md),

                            // Shipment Type Badge
                            WawStatusBadge(
                              label: isRTL
                                  ? shipmentType.arabicLabel
                                  : shipmentType.frenchLabel,
                              color: shipmentType.color,
                              icon: shipmentType.icon,
                            ),

                            if (breakdown.multiplier != 1.0) ...[
                              SizedBox(height: WawAppSpacing.xs),
                              Text(
                                ShipmentPricingMultipliers
                                    .getMultiplierDescription(shipmentType),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: shipmentType.color,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],

                            SizedBox(height: WawAppSpacing.md),
                            Divider(color: context.wawAppTheme.dividerColor),
                            SizedBox(height: WawAppSpacing.md),

                            // Price Breakdown
                            _buildPriceBreakdown(context, l10n, breakdown),
                          ],
                        ],
                      );
                    },
                  ),
                ),

                // Distance & Time Card
                if (quoteState.distanceKm != null) ...[
                  SizedBox(height: WawAppSpacing.md),
                  WawCard(
                    elevation: WawAppElevation.low,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoColumn(
                              context,
                              icon: Icons.straighten,
                              label: l10n.distance,
                              value:
                                  '${quoteState.distanceKm!.toStringAsFixed(1)} ${l10n.km}',
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: context.wawAppTheme.dividerColor,
                            ),
                            _buildInfoColumn(
                              context,
                              icon: Icons.access_time,
                              label: l10n.estimated_time,
                              value:
                                  '${Eta.minutesFromKm(quoteState.distanceKm!).ceil()} ${l10n.minute}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: WawAppSpacing.xl),

                // Request Button
                WawActionButton(
                  label: l10n.request_now,
                  icon: Icons.check_circle,
                  onPressed: quoteState.isReady ? _handleRequestOrder : null,
                  isLoading: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown(
      BuildContext context, AppLocalizations l10n, PricingBreakdown breakdown) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _buildBreakdownRow(
            context, l10n.base_price, '${breakdown.base} ${l10n.currency}'),
        SizedBox(height: WawAppSpacing.xs),
        _buildBreakdownRow(context, l10n.distance_cost,
            '${breakdown.distancePart} ${l10n.currency}'),
        if (breakdown.multiplier != 1.0) ...[
          SizedBox(height: WawAppSpacing.xs),
          _buildBreakdownRow(
            context,
            l10n.shipment_multiplier,
            '× ${breakdown.multiplier.toStringAsFixed(2)}',
            color: theme.colorScheme.primary,
          ),
        ],
        SizedBox(height: WawAppSpacing.xs),
        Divider(color: context.wawAppTheme.dividerColor),
        SizedBox(height: WawAppSpacing.xs),
        _buildBreakdownRow(
          context,
          l10n.total,
          '${breakdown.rounded} ${l10n.currency}',
          isBold: true,
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label, String value,
      {bool isBold = false, Color? color}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(BuildContext context,
      {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 28),
        SizedBox(height: WawAppSpacing.xs),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
        SizedBox(height: WawAppSpacing.xxs),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Future<void> _handleRequestOrder() async {
    final l10n = AppLocalizations.of(context)!;
    final quoteState = ref.read(quoteProvider);

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

      // Get selected shipment type and compute price with it
      final shipmentType = ref.read(selectedShipmentTypeProvider);
      final breakdown = Pricing.computeWithShipmentType(
        quoteState.distanceKm!,
        shipmentType,
      );

      final authState = ref.read(authProvider);
      final user = authState.user;
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
      final order = core.Order(
        distanceKm: quoteState.distanceKm!,
        price: breakdown.rounded.toDouble(),
        pickupAddress: fromText,
        dropoffAddress: toText,
        pickup: LocationPoint(
          lat: routeState.pickup!.latitude,
          lng: routeState.pickup!.longitude,
          label: fromText,
        ),
        dropoff: LocationPoint(
          lat: routeState.dropoff!.latitude,
          lng: routeState.dropoff!.longitude,
          label: toText,
        ),
        status: OrderStatus.assigning.toFirestore(),
      );

      _startOrderTracking(orderId);
      if (!mounted) return;
      context.push('/track', extra: order);
    } catch (e, stackTrace) {
      // Debug logging for future diagnostics
      debugPrint('[OrdersClient] Failed to create order: $e');
      debugPrint('[OrdersClient] Stack trace: $stackTrace');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.error_create_order),
          backgroundColor: context.errorColor,
        ),
      );
    }
  }
}
