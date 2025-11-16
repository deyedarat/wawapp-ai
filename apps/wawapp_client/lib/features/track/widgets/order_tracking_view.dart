import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../l10n/app_localizations.dart';
import '../models/order.dart' as app_order;
import 'order_status_timeline.dart';

class OrderTrackingView extends StatefulWidget {
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
  State<OrderTrackingView> createState() => _OrderTrackingViewState();
}

class _OrderTrackingViewState extends State<OrderTrackingView> {
  GoogleMapController? _mapController;

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
          LatLng(widget.order!.dropoff.latitude, widget.order!.dropoff.longitude),
        ],
        color: Theme.of(context).colorScheme.primary,
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ));
    }

    return polylines;
  }

  Set<Marker> _buildMarkers() {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: GoogleMap(
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
            },
            initialCameraPosition: widget.order?.pickup != null
                ? CameraPosition(
                    target: LatLng(widget.order!.pickup.latitude,
                        widget.order!.pickup.longitude),
                    zoom: 14.0,
                  )
                : _nouakchott,
            myLocationEnabled: !widget.readOnly,
            myLocationButtonEnabled: !widget.readOnly,
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            compassEnabled: true,
            mapToolbarEnabled: false,
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
                        final trackUrl =
                            'https://wawapp.page.link/track/${widget.order?.hashCode ?? 'unknown'}';
                        await Clipboard.setData(ClipboardData(text: trackUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ رابط التتبع')),
                          );
                        }
                      },
                      child: const Text('نسخ رابط التتبع'),
                    ),
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