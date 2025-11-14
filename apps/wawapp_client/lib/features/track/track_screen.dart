import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../l10n/app_localizations.dart';
import '../../core/location/location_service.dart';
import 'models/order.dart' as app_order;
import 'widgets/order_status_timeline.dart';

class TrackScreen extends ConsumerStatefulWidget {
  final app_order.Order? order;
  const TrackScreen({super.key, this.order});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> {
  GoogleMapController? _mapController;
  StreamSubscription? _positionSubscription;
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  LatLng? _currentPosition;
  String? _orderId;
  bool _hasNavigated = false;

  static const CameraPosition _nouakchott = CameraPosition(
    target: LatLng(18.0735, -15.9582),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _startOrderTracking();
  }

  void _startOrderTracking() async {
    if (widget.order == null) return;

    final user = await FirebaseFirestore.instance
        .collection('orders')
        .where('ownerId', isEqualTo: widget.order!.status)
        .limit(1)
        .get();

    if (user.docs.isEmpty) return;
    _orderId = user.docs.first.id;

    _orderSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(_orderId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted || _hasNavigated) return;

      final data = snapshot.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'accepted' && !_hasNavigated) {
        _hasNavigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/driver-found/$_orderId');
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionSubscription = LocationService.getPositionStream().listen(
      (position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(_currentPosition!),
        );
      },
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    if (_currentPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position: _currentPosition!,
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

  static String getArabicStatus(String? status) {
    switch (status) {
      case 'pending':
        return 'قيد الإنشاء';
      case 'matching':
        return 'جارِ التعيين';
      case 'assigned':
        return 'تم التعيين';
      case 'enRoute':
        return 'في الطريق';
      case 'pickedUp':
        return 'تم الاستلام';
      case 'delivering':
        return 'جاري التوصيل';
      case 'delivered':
        return 'تم التسليم';
      default:
        return status ?? 'قيد الإنشاء';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(kReleaseMode ? l10n.track : '${l10n.track} • DEBUG'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: GoogleMap(
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _fitBounds());
                  },
                  initialCameraPosition: widget.order?.pickup != null
                      ? CameraPosition(
                          target: LatLng(widget.order!.pickup.latitude,
                              widget.order!.pickup.longitude),
                          zoom: 14.0,
                        )
                      : _nouakchott,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: _buildMarkers(),
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
                        OrderStatusTimeline(
                            status: widget.order!.status ?? 'pending'),
                        const SizedBox(height: 12),
                        Text('الحالة: ${getArabicStatus(widget.order!.status)}',
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
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final trackUrl =
                                'https://wawapp.page.link/track/${widget.order?.hashCode ?? 'unknown'}';
                            await Clipboard.setData(
                                ClipboardData(text: trackUrl));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('تم نسخ رابط التتبع')),
                              );
                            }
                          },
                          child: const Text('نسخ رابط التتبع'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
