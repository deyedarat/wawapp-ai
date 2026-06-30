import 'dart:math' as math;

import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/maps/safe_camera_helper.dart';
import '../../../l10n/app_localizations.dart';
import '../../map/providers/district_layer_provider.dart';
import '../data/orders_repository.dart';
import '../providers/order_tracking_provider.dart';
import 'order_status_timeline.dart';
import 'rating_bottom_sheet.dart';

class OrderTrackingView extends ConsumerStatefulWidget {
  final Order? order;
  final bool readOnly;
  final LatLng? currentPosition;

  const OrderTrackingView({super.key, required this.order, this.readOnly = false, this.currentPosition});

  @override
  ConsumerState<OrderTrackingView> createState() => _OrderTrackingViewState();
}

class _OrderTrackingViewState extends ConsumerState<OrderTrackingView> with SafeCameraMixin {
  bool _isFollowingDriver = true;
  LatLng? _lastDriverPosition;
  bool _isCancelling = false;
  bool _hasShownRatingPrompt = false;

  @override
  void initState() {
    super.initState();
    if (widget.order?.driverId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.listen(driverLocationProvider(widget.order!.id!), (previous, next) {
            next.whenData((location) {
              if (location != null && mounted) {
                _handleDriverMovement(location);
                _showRatingPrompt();
              }
            });
          });
        }
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    ref.read(currentZoomProvider.notifier).state = position.zoom;
  }

  static const CameraPosition _nouakchott = CameraPosition(target: LatLng(18.0735, -15.9582), zoom: 14.0);

  Set<Polyline> _buildPolylines() {
    final polylines = <Polyline>{};

    if (widget.order?.pickup != null && widget.order?.dropoff != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
            LatLng(widget.order!.dropoff.latitude, widget.order!.dropoff.longitude),
          ],
          color: Colors.green,
          width: 5,
        ),
      );
    }

    return polylines;
  }

  Set<Marker> _buildMarkers(DriverLocation? driverLocation) {
    final markers = <Marker>{};

    if (widget.order?.pickup != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'استلام', snippet: widget.order!.pickupAddress),
        ),
      );
    }

    if (widget.order?.dropoff != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(widget.order!.dropoff.latitude, widget.order!.dropoff.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'تسليم', snippet: widget.order!.dropoffAddress),
        ),
      );
    }

    if (driverLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver'),
          position: driverLocation.position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'السائق'),
        ),
      );
    }

    return markers;
  }

  void _fitBounds() {
    final pickup = widget.order?.pickup;
    final dropoff = widget.order?.dropoff;

    if (pickup != null && dropoff != null) {
      final bounds = LatLngBounds(
        southwest: LatLng(
          pickup.latitude < dropoff.latitude ? pickup.latitude : dropoff.latitude,
          pickup.longitude < dropoff.longitude ? pickup.longitude : dropoff.longitude,
        ),
        northeast: LatLng(
          pickup.latitude > dropoff.latitude ? pickup.latitude : dropoff.latitude,
          pickup.longitude > dropoff.longitude ? pickup.longitude : dropoff.longitude,
        ),
      );
      safeAnimateCamera(CameraUpdate.newLatLngBounds(bounds, 48.0), action: 'fit_bounds');
    } else if (pickup != null) {
      safeAnimateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pickup.latitude, pickup.longitude), 15.0),
        action: 'fit_pickup',
      );
    }
  }

  void _handleDriverMovement(DriverLocation? driverLocation) {
    if (driverLocation == null || !_isFollowingDriver || !isMapReady) {
      return;
    }

    final currentPos = driverLocation.position;

    if (_lastDriverPosition != null) {
      final distance = _calculateDistance(
        _lastDriverPosition!.latitude,
        _lastDriverPosition!.longitude,
        currentPos.latitude,
        currentPos.longitude,
      );
      if (distance < 100) return;
    }

    _lastDriverPosition = currentPos;
    safeAnimateCamera(CameraUpdate.newLatLngZoom(currentPos, 16.0), action: 'follow_driver');
  }

  void _recenterOnDriver(DriverLocation driverLocation) {
    setState(() {
      _isFollowingDriver = true;
    });

    safeAnimateCamera(CameraUpdate.newLatLngZoom(driverLocation.position, 16.0), action: 'recenter_driver');
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000;
    final double dLat = (lat2 - lat1) * (math.pi / 180);
    final double dLon = (lon2 - lon1) * (math.pi / 180);
    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  Future<void> _showCancelDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل تريد إلغاء الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('لا')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الطلب')));
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        final message = e.toString().contains('current status')
            ? 'لا يمكن إلغاء الطلب الآن، ربما تم قبوله أو تغيّرت حالته.'
            : 'تعذّر إلغاء الطلب، حاول مرة أخرى.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void _showRatingPrompt() {
    if (_hasShownRatingPrompt || widget.readOnly) return;

    final order = widget.order;
    if (order == null || order.orderStatus != OrderStatus.completed || order.driverRating != null) {
      return;
    }

    _hasShownRatingPrompt = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => RatingBottomSheet(orderId: order.id!, onRated: () => setState(() {})),
        );
      }
    });
  }

  String _formatOrderId(String? id) {
    if (id == null) return '---';
    // Generate a numeric order ID from the timestamp or use the createdAt
    final createdAt = widget.order?.createdAt;
    if (createdAt != null) {
      final formatter = DateFormat('yyyyMMddHHmm');
      return formatter.format(createdAt);
    }
    // Fallback: use last 12 chars of ID
    return id.length > 12 ? id.substring(id.length - 12) : id;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final driverLocationAsync = widget.order?.driverId != null
        ? ref.watch(driverLocationProvider(widget.order!.id!))
        : null;

    final driverLocation = driverLocationAsync?.whenOrNull(data: (location) => location);

    return Column(
      children: [
        // Map section
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.38,
          child: Stack(
            children: [
              Consumer(
                builder: (context, ref, child) {
                  final polygons = ref.watch(districtPolygonsProvider);
                  final locale = Localizations.localeOf(context);
                  final markersAsync = ref.watch(districtMarkersProvider(locale.languageCode));

                  return markersAsync.when(
                    data: (districtMarkers) => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        onMapCreated(controller);
                        scheduleCameraOperation(() => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: false,
                      markers: {..._buildMarkers(driverLocation), ...districtMarkers},
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    loading: () => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        onMapCreated(controller);
                        scheduleCameraOperation(() => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: false,
                      markers: _buildMarkers(driverLocation),
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    error: (error, stack) => GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        onMapCreated(controller);
                        scheduleCameraOperation(() => _fitBounds());
                      },
                      onCameraMoveStarted: () {
                        _isFollowingDriver = false;
                      },
                      onCameraMove: _onCameraMove,
                      initialCameraPosition: widget.order?.pickup != null
                          ? CameraPosition(
                              target: LatLng(widget.order!.pickup.latitude, widget.order!.pickup.longitude),
                              zoom: 14.0,
                            )
                          : _nouakchott,
                      myLocationEnabled: !widget.readOnly,
                      myLocationButtonEnabled: false,
                      markers: _buildMarkers(driverLocation),
                      polylines: _buildPolylines(),
                      polygons: polygons,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                  );
                },
              ),
              // Recenter button
              if (driverLocation != null && !widget.readOnly)
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: FloatingActionButton.small(
                    onPressed: () => _recenterOnDriver(driverLocation),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.navigation_outlined),
                  ),
                ),
            ],
          ),
        ),

        // Details section below map
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // Status timeline stepper
                if (widget.order != null) OrderStatusTimeline(status: widget.order!.orderStatus),

                const SizedBox(height: 12),

                // Status badge
                if (widget.order != null) _buildStatusBadge(theme),

                const SizedBox(height: 16),

                // Price and distance boxes
                if (widget.order != null) _buildInfoBoxes(theme, l10n),

                const SizedBox(height: 12),

                // Route card (from/to)
                if (widget.order != null) _buildRouteCard(theme),

                const SizedBox(height: 12),

                // Bottom info row (driver, vehicle, order number)
                if (widget.order != null) _buildBottomInfoRow(theme),

                // Cancel button
                if (!widget.readOnly && widget.order != null && widget.order!.orderStatus.canClientCancel) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isCancelling ? null : () => _showCancelDialog(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isCancelling
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cancel_outlined),
                      label: const Text('إلغاء الطلب'),
                    ),
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    final status = widget.order!.orderStatus;
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('الحالة:', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                status.toArabicLabel(),
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBoxes(ThemeData theme, AppLocalizations l10n) {
    return Row(
      children: [
        // Price box
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text('السعر', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.order!.price.toInt()} أوقية',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Distance box
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text('المسافة', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.order!.distanceKm.toStringAsFixed(1)} كم',
                      style: theme.textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        children: [
          // Pickup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                  ),
                  Container(width: 2, height: 30, color: Colors.grey.shade700),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('من', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green, fontSize: 11)),
                    Text(
                      widget.order!.pickupAddress,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Dropoff
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('إلى', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red, fontSize: 11)),
                    Text(
                      widget.order!.dropoffAddress,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfoRow(ThemeData theme) {
    final driverName = widget.order?.driverName;
    final vehiclePlate = widget.order?.driverVehiclePlate;
    final orderId = _formatOrderId(widget.order?.id);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        children: [
          // Order number
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'رقم الطلب',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  orderId,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade800),
          // Vehicle
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'المركبة',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  vehiclePlate ?? '—',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade800),
          // Driver
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'السائق',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  driverName ?? '—',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelledByClient:
      case OrderStatus.cancelledByDriver:
      case OrderStatus.cancelledBySystem:
      case OrderStatus.cancelledByAdmin:
        return Colors.red;
      case OrderStatus.expired:
        return Colors.orange;
      case OrderStatus.onRoute:
        return Colors.blue;
      default:
        return Colors.green;
    }
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return Icons.check_circle;
      case OrderStatus.cancelledByClient:
      case OrderStatus.cancelledByDriver:
      case OrderStatus.cancelledBySystem:
      case OrderStatus.cancelledByAdmin:
        return Icons.cancel;
      case OrderStatus.expired:
        return Icons.timer_off;
      case OrderStatus.onRoute:
        return Icons.local_shipping;
      default:
        return Icons.hourglass_empty;
    }
  }
}
