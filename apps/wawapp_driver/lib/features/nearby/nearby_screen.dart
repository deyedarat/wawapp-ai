import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:core_shared/core_shared.dart';
import '../../l10n/app_localizations.dart';
import 'package:geolocator/geolocator.dart';
import '../../../models/order.dart' as app_order;
import '../../../services/location_service.dart';
import '../../../services/orders_service.dart';
import '../../../widgets/error_screen.dart';
import 'dart:math';
import 'dart:developer' as dev;

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final _ordersService = OrdersService();
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
      await _ordersService.acceptOrder(orderId);
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
                : StreamBuilder<List<app_order.Order>>(
                    stream: () {
                      if (kDebugMode) {
                        dev.log(
                            '[Matching] NearbyScreen: Subscribing to nearby orders stream');
                      }
                      return _ordersService.getNearbyOrders(_currentPosition!);
                    }(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        if (kDebugMode) {
                          dev.log(
                              '[Matching] NearbyScreen: Waiting for stream data');
                        }
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        if (kDebugMode) {
                          dev.log(
                              '[Matching] NearbyScreen: Stream error: ${snapshot.error}');
                        }
                        final appError = AppError.from(snapshot.error!);
                        return ErrorScreen(
                          message: appError.toUserMessage(),
                          onRetry: () => setState(() {}),
                        );
                      }
                      final orders = snapshot.data ?? [];
                      if (kDebugMode) {
                        dev.log(
                            '[Matching] NearbyScreen: Displaying ${orders.length} orders');
                      }
                      if (orders.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('لا توجد طلبات قريبة'),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final distance = _calculateDistance(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                            order.pickup.lat,
                            order.pickup.lng,
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.local_shipping, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'طلب #${order.id.substring(order.id.length - 6)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'المسافة: ${distance.toStringAsFixed(1)} كم',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        const SizedBox(height: 2),
                                        Text('من: ${order.pickup.label}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text('إلى: ${order.dropoff.label}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${order.price} MRU',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () => _acceptOrder(order.id),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 8),
                                        ),
                                        child: const Text('قبول'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
