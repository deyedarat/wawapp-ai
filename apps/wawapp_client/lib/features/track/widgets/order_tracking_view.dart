import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../models/order.dart' as app_order;
import '../providers/order_tracking_provider.dart';
import '../data/orders_repository.dart';
import 'order_status_timeline.dart';
import 'rating_bottom_sheet.dart';
import '../../map/providers/district_layer_provider.dart';

class OrderTrackingView extends ConsumerStatefulWidget {
  final app_order.Order? order;
  final bool readOnly;
  final LatLng? currentPosition;

  const OrderTrackingView({
    super.key,
    required this.order,
    this.readOnly = false,
    this.currentPosition,
  });

  @override
  ConsumerState<OrderTrackingView> createState() => _OrderTrackingViewState();
}

class _OrderTrackingViewState extends ConsumerState<OrderTrackingView> {
  GoogleMapController? _mapController;
  bool _isFollowingDriver = true;
  LatLng? _lastDriverPosition;
  bool _isCancelling = false;
  bool _hasShownRatingPrompt = false;

  void _onCameraMove(CameraPosition position) {
    ref.read(currentZoomProvider.notifier).state = position.zoom;
  }

  static const CameraPosition _nouakchott = CameraPosition(
    target: LatLng(18.0735, -15.9582),
    zoom: 14.0,
  );

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (widget.order?.pickup != null && widget.order?.dropoff != null) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: [
          LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
          LatLng(
              widget.order!.dropoff.latitude, widget.order!.dropoff.longitude),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    return polylines;
  }

  Set<Marker> _buildMarkers(DriverLocation? driverLocation) {
    final markers = <Marker>{};

    if (widget.currentPosition != null && !widget.readOnly) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position: widget.currentPosition!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'موقعك الحالي'),
      ));
    }

    if (widget.order?.pickup != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
            widget.order!.pickup.latitude, widget.order!.pickup.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow:
            InfoWindow(title: 'استلام', snippet: widget.order!.pickupAddress),
      ));
    }

    if (widget.order?.dropoff != null) {
      markers.add(Marker(
        markerId: const MarkerId('dropoff'),
        position: LatLng(
            widget.order!.dropoff.latitude, widget.order!.dropoff.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow:
            InfoWindow(title: 'تسليم', snippet: widget.order!.dropoffAddress),
      ));
    }

    // Add driver marker if available
    if (driverLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation.position,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'السائق'),
      ));
    }

    return markers;
  }

  void _fitBounds() {
    if (_mapController == null) return;

    final pickup = widget.order?.pickup;
    final dropoff = widget.order?.dropoff;

    if (pickup != null && dropoff != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          pickup.latitude < dropoff.latitude
              ? pickup.latitude
              : dropoff.latitude,
          pickup.longitude < dropoff.longitude
              ? pickup.longitude
              : dropoff.longitude,
        ),
        northeast: LatLng(
          pickup.latitude > dropoff.latitude
              ? pickup.latitude
              : dropoff.latitude,
          pickup.longitude > dropoff.longitude
              ? pickup.longitude
              : dropoff.longitude,
        ),
      );
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 48.0));
    } else if (pickup != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15.0));
    }
  }

  void _handleDriverMovement(DriverLocation? driverLocation) {
    if (_mapController == null ||
        driverLocation == null ||
        !_isFollowingDriver) {
      return;
    }

    final currentPos = driverLocation.position;

    // Only animate if driver moved significantly (>50 meters)
    if (_lastDriverPosition != null) {
      final distance = _calculateDistance(
        _lastDriverPosition!.latitude,
        _lastDriverPosition!.longitude,
        currentPos.latitude,
        currentPos.longitude,
      );
      if (distance < 50) return;
    }

    _lastDriverPosition = currentPos;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(currentPos, 16.0),
    );
  }

  void _recenterOnDriver(DriverLocation driverLocation) {
    if (_mapController == null) return;

    setState(() {
      _isFollowingDriver = true;
    });

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(driverLocation.position, 16.0),
    );
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل تريد إلغاء الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('لا'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('نعم'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _cancelOrder();
    }
  }

  Future<void> _cancelOrder() async {
    if (widget.order == null || widget.order!.id == null) return;

    setState(() => _isCancelling = true);

    try {
      final repository = ref.read(ordersRepositoryProvider);
      await repository.cancelOrder(widget.order!.id!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الطلب')),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        final message = e.toString().contains('current status')
            ? 'لا يمكن إلغاء الطلب الآن، ربما تم قبوله أو تغيّرت حالته.'
            : 'تعذّر إلغاء الطلب، حاول مرة أخرى.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  void _showRatingPrompt() {
    if (_hasShownRatingPrompt || widget.readOnly) return;
    
    final order = widget.order;
    if (order == null || 
        order.orderStatus != OrderStatus.completed || 
        order.driverRating != null) {
      return;
    }

    _hasShownRatingPrompt = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RatingBottomSheet(
            orderId: order.id!,
            onRated: () => setState(() {}),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Watch driver location if order has a driver
    final driverLocationAsync = widget.order?.driverId != null
        ? ref.watch(driverLocationProvider(widget.order!.driverId!))
        : null;

    final driverLocation = driverLocationAsync?.whenOrNull(
      data: (location) => location,
    );

    // Handle driver movement for auto-follow and rating prompt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDriverMovement(driverLocation);
      _showRatingPrompt();
    });

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Stack(
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final polygons = ref.watch(districtPolygonsProvider);
                  final locale = Localizations.localeOf(context);
                  final markersAsync =
                      ref.watch(districtMarkersProvider(locale.languageCode));

                  return markersAsync.when(
                    data: (districtMarkers) => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude,
                                  widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: !widget.readOnly,
                      markers: {
                        ..._buildMarkers(driverLocation),
                        ...districtMarkers
                      },
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                    loading: () => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude,
                                  widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: !widget.readOnly,
                      markers: _buildMarkers(driverLocation),
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                    error: (error, stack) => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude,
                                  widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: !widget.readOnly,
                      markers: _buildMarkers(driverLocation),
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                  );
                },
              ),
              if (driverLocation != null && !widget.readOnly)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    onPressed: () => _recenterOnDriver(driverLocation),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.my_location),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.order != null) ...[
                  OrderStatusTimeline(status: widget.order!.orderStatus),
                  const SizedBox(height: 12),
                  Text('الحالة: ${widget.order!.orderStatus.toArabicLabel()}',
                      style: Theme.of(context).textTheme.titleMedium),
                ] else
                  Text('الحالة: في الطريق',
                      style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text('السائق: ---'),
                const Text('المركبة: ---'),
                Text(
                    'السعر: ${widget.order?.price.round() ?? '---'} ${l10n.currency}'),
                if (widget.order != null) ...[
                  Text('المسافة: ${widget.order!.distanceKm} كم'),
                  Text('من: ${widget.order!.pickupAddress}'),
                  Text('إلى: ${widget.order!.dropoffAddress}'),
                  if (!widget.readOnly) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final String orderId = widget.order!.id ?? 'unknown';
                        await Clipboard.setData(ClipboardData(
                            text: 'https://wawapp.page.link/track/$orderId'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ رابط التتبع')),
                          );
                        }
                      },
                      child: const Text('نسخ رابط التتبع'),
                    ),
                    if (widget.order!.orderStatus.canClientCancel) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _isCancelling
                            ? null
                            : () => _showCancelDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
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
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
