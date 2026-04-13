import 'dart:developer' as dev;

import 'package:core_shared/core_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/components.dart';
import '../../services/orders_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/error_screen.dart';
import '../auth/providers/auth_service_provider.dart';
import 'providers/active_order_provider.dart';
import 'widgets/accepted_countdown_banner.dart';
import 'widgets/cancel_order_dialog.dart';

class ActiveOrderScreen extends ConsumerStatefulWidget {
  const ActiveOrderScreen({super.key});

  @override
  ConsumerState<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends ConsumerState<ActiveOrderScreen> {
  bool _isTrackingStarted = false;
  bool _isCancelling = false;
  bool _isStartingTrip = false;
  GoogleMapController? _mapController;

  @override
  void dispose() {
    if (_isTrackingStarted) {
      TrackingService.instance.stopTracking();
    }
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _transition(String orderId, OrderStatus to) async {
    if (to == OrderStatus.onRoute) {
      setState(() => _isStartingTrip = true);
    }

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.transition(orderId, to);
      if (!mounted) return;

      if (to == OrderStatus.onRoute) {
        setState(() => _isStartingTrip = false);
      }

      final message = to == OrderStatus.onRoute
          ? 'تم بدء الرحلة بنجاح ✓'
          : to == OrderStatus.completed
              ? 'تم إكمال الطلب بنجاح ✓'
              : 'تم تحديث حالة الطلب';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );

      if (to == OrderStatus.completed) {
        context.go('/nearby');
      }
    } on Object catch (e) {
      if (!mounted) return;

      if (to == OrderStatus.onRoute) {
        setState(() => _isStartingTrip = false);
      }

      final err = e.toString().toLowerCase();
      String errorMessage;
      Duration duration = const Duration(seconds: 4);

      if (err.contains('insufficient') ||
          err.contains('balance') ||
          err.contains('رصيد')) {
        errorMessage =
            '⚠️ رصيد محفظتك غير كافٍ لبدء الرحلة\n\nيرجى شحن المحفظة أولاً';
        duration = const Duration(seconds: 6);
      } else if (err.contains('status')) {
        errorMessage = 'لا يمكن تحديث الطلب الآن، ربما تغيّرت حالته.';
      } else if (err.contains('network') || err.contains('connection')) {
        errorMessage = 'خطأ في الاتصال، تحقق من الإنترنت وحاول مرة أخرى';
      } else {
        errorMessage = 'تعذّر تحديث الطلب: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: duration,
          action: SnackBarAction(
              label: 'حسناً', textColor: Colors.white, onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _showCancelDialog(String orderId) async {
    final reason = await showCancelOrderDialog(context);
    if (reason != null && mounted) {
      await _cancelOrder(orderId, reason);
    }
  }

  Future<void> _cancelOrder(String orderId, CancelReason reason) async {
    setState(() => _isCancelling = true);

    try {
      final ordersService = ref.read(ordersServiceProvider);
      await ordersService.cancelOrder(orderId, reason: reason);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الطلب بواسطة السائق')),
        );
        context.go('/nearby');
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إجراء المكالمة')),
        );
      }
    }
  }

  Future<void> _openMaps(double lat, double lng, String label) async {
    final googleMapsUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح الخرائط')),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
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

            // Calculate map center and markers
            final pickupLatLng = LatLng(order.pickup.lat, order.pickup.lng);
            final dropoffLatLng = LatLng(order.dropoff.lat, order.dropoff.lng);

            // Calculate bounds to show both pickup and dropoff
            final bounds = LatLngBounds(
              southwest: LatLng(
                order.pickup.lat < order.dropoff.lat
                    ? order.pickup.lat
                    : order.dropoff.lat,
                order.pickup.lng < order.dropoff.lng
                    ? order.pickup.lng
                    : order.dropoff.lng,
              ),
              northeast: LatLng(
                order.pickup.lat > order.dropoff.lat
                    ? order.pickup.lat
                    : order.dropoff.lat,
                order.pickup.lng > order.dropoff.lng
                    ? order.pickup.lng
                    : order.dropoff.lng,
              ),
            );

            return Column(
              children: [
                // Countdown banner for accepted orders
                if (order.orderStatus == OrderStatus.accepted)
                  const AcceptedCountdownBanner(),

                // Map View — fixed height to ensure visibility
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.35,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: pickupLatLng,
                      zoom: 13,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: pickupLatLng,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                        infoWindow: InfoWindow(
                          title: 'نقطة الالتقاط',
                          snippet: order.pickup.label,
                        ),
                      ),
                      Marker(
                        markerId: const MarkerId('dropoff'),
                        position: dropoffLatLng,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed),
                        infoWindow: InfoWindow(
                          title: 'نقطة التوصيل',
                          snippet: order.dropoff.label,
                        ),
                      ),
                    },
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        points: [pickupLatLng, dropoffLatLng],
                        color: DriverAppColors.primaryLight,
                        width: 5,
                      ),
                    },
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Fit bounds to show both markers
                      Future.delayed(const Duration(milliseconds: 500), () {
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 80),
                        );
                      });
                    },
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                ),

                // Order Details Card
                Expanded(
                  child: SingleChildScrollView(
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
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'طلب #${order.id != null && order.id!.length > 6 ? order.id!.substring(order.id!.length - 6) : order.id ?? 'N/A'}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.location_on,
                                      color: Colors.green),
                                  title: const Text('من',
                                      style: TextStyle(fontSize: 12)),
                                  subtitle: Text(order.pickup.label),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.map, size: 20),
                                    onPressed: () => _openMaps(
                                      order.pickup.lat,
                                      order.pickup.lng,
                                      order.pickup.label,
                                    ),
                                  ),
                                ),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.location_on,
                                      color: Colors.red),
                                  title: const Text('إلى',
                                      style: TextStyle(fontSize: 12)),
                                  subtitle: Text(order.dropoff.label),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.map, size: 20),
                                    onPressed: () => _openMaps(
                                      order.dropoff.lat,
                                      order.dropoff.lng,
                                      order.dropoff.label,
                                    ),
                                  ),
                                ),
                                const Divider(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        'المسافة: ${order.distanceKm.toStringAsFixed(1)} كم'),
                                    Text('السعر: ${order.price} MRU',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                    'الحالة: ${order.orderStatus.toArabicLabel()}',
                                    style: TextStyle(
                                        color: _getStatusColor(
                                            order.orderStatus))),
                              ],
                            ),
                          ),
                        ),
                        // Customer Phone Card - Prominent
                        if (order.customerPhone != null &&
                            order.customerPhone!.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.only(top: 16, bottom: 0),
                            color: const Color(0xFFF1F8E9),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: DriverAppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                    child: const Icon(Icons.phone,
                                        color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'رقم العميل',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          order.customerPhone!,
                                          style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: Colors.black87),
                                          textDirection: TextDirection.ltr,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _makePhoneCall(order.customerPhone!),
                                    icon: const Icon(Icons.call, size: 20),
                                    label: const Text('اتصل'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Fee warning for trip start
                        if (order.orderStatus.canDriverStartTrip)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              border: Border.all(color: Colors.orange),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.orange.shade700),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'سيتم اقتطاع ${(order.price * 0.1).toStringAsFixed(0)} أوقية عند بدء الرحلة',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange.shade900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ElevatedButton(
                          onPressed: order.orderStatus.canDriverStartTrip &&
                                  order.id != null &&
                                  !_isStartingTrip
                              ? () =>
                                  _transition(order.id!, OrderStatus.onRoute)
                              : null,
                          child: _isStartingTrip
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text('جارِ بدء الرحلة...'),
                                  ],
                                )
                              : const Text('بدء الرحلة'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: order.orderStatus.canDriverCompleteTrip &&
                                  order.id != null
                              ? () =>
                                  _transition(order.id!, OrderStatus.completed)
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
                            side: const BorderSide(
                                color: DriverAppColors.accentRed),
                          ),
                          child: _isCancelling
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('إلغاء الطلب'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.accepted:
        return DriverAppColors.primaryLight;
      case OrderStatus.onRoute:
        return DriverAppColors.infoLight;
      case OrderStatus.completed:
        return DriverAppColors.successLight;
      case OrderStatus.cancelledByClient:
      case OrderStatus.cancelledByDriver:
        return DriverAppColors.errorLight;
      default:
        return Colors.grey;
    }
  }
}
