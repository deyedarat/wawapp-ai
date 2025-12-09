import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../../services/location_service.dart';
import '../../../services/orders_service.dart';
import '../../../widgets/error_screen.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import 'providers/nearby_orders_provider.dart';
import 'dart:math';
import 'dart:developer' as dev;

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  final _locationService = LocationService.instance;
  Position? _currentPosition;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (kDebugMode) {
      dev.log('[Matching] NearbyScreen: Initializing location');
    }
    try {
      _currentPosition = await _locationService.getCurrentPosition();
      if (kDebugMode) {
        dev.log(
            '[Matching] NearbyScreen: Location obtained: lat=${_currentPosition!.latitude.toStringAsFixed(4)}, lng=${_currentPosition!.longitude.toStringAsFixed(4)}');
      }
      setState(() {});
    } on Object catch (e) {
      if (kDebugMode) {
        dev.log('[Matching] NearbyScreen: Location error: $e');
      }
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.acceptOrder(orderId);
      if (!mounted) {
        return;
      }
      context.go('/active-order');
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'خطأ: ${e.toString().contains('already taken') ? 'تم أخذ الطلب بالفعل' : e.toString()}')),
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.nearby_requests),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _initLocation,
            ),
          ],
        ),
        body: _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في الموقع: $_error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initLocation,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            : _currentPosition == null
                ? const Center(child: CircularProgressIndicator())
                : _buildOrdersList(),
      ),
    );
  }

  Widget _buildOrdersList() {
    if (kDebugMode) {
      dev.log('[Matching] NearbyScreen: Subscribing to nearby orders stream');
    }

    final ordersAsync = ref.watch(nearbyOrdersProvider(_currentPosition!));

    return ordersAsync.when(
      loading: () {
        if (kDebugMode) {
          dev.log('[Matching] NearbyScreen: Waiting for stream data');
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (error, stack) {
        if (kDebugMode) {
          dev.log('[Matching] NearbyScreen: Stream error: $error');
        }
        final appError = AppError.from(error);
        return ErrorScreen(
          message: appError.toUserMessage(),
          onRetry: () => ref.refresh(nearbyOrdersProvider(_currentPosition!)),
        );
      },
      data: (orders) {
        if (kDebugMode) {
          dev.log('[Matching] NearbyScreen: Displaying ${orders.length} orders');
        }
        if (orders.isEmpty) {
          return const DriverEmptyState(
            icon: Icons.inbox,
            message: 'لا توجد طلبات قريبة في الوقت الحالي',
          );
        }
        return ListView.builder(
          padding: EdgeInsets.all(DriverAppSpacing.md),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              order.pickup.lat,
              order.pickup.lng,
            );
            return DriverCard(
              padding: EdgeInsets.all(DriverAppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(DriverAppSpacing.sm),
                            decoration: BoxDecoration(
                              color: DriverAppColors.primaryLight.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_shipping,
                              size: 24,
                              color: DriverAppColors.primaryLight,
                            ),
                          ),
                          SizedBox(width: DriverAppSpacing.sm),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'طلب #${order.id != null && order.id!.length > 6 ? order.id!.substring(order.id!.length - 6) : order.id ?? 'N/A'}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'المسافة: ${distance.toStringAsFixed(1)} كم',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: DriverAppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: DriverAppSpacing.sm,
                          vertical: DriverAppSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: DriverAppColors.successLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(DriverAppSpacing.radiusFull),
                        ),
                        child: Text(
                          '${order.price} MRU',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: DriverAppColors.successLight,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DriverAppSpacing.md),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: DriverAppColors.successLight,
                      ),
                      SizedBox(width: DriverAppSpacing.xs),
                      Expanded(
                        child: Text(
                          order.pickup.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DriverAppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.flag,
                        size: 16,
                        color: DriverAppColors.errorLight,
                      ),
                      SizedBox(width: DriverAppSpacing.xs),
                      Expanded(
                        child: Text(
                          order.dropoff.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: DriverAppSpacing.md),
                  DriverActionButton(
                    label: 'قبول الطلب',
                    icon: Icons.check_circle,
                    onPressed: order.id != null ? () => _acceptOrder(order.id!) : null,
                    isFullWidth: true,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
