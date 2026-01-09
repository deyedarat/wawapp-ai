import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/maps/safe_camera_helper.dart';
import '../../widgets/error_screen.dart';
import '../map/providers/district_layer_provider.dart';
import 'providers/order_tracking_provider.dart';

class DriverFoundScreen extends ConsumerWidget {
  final String orderId;

  const DriverFoundScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      appBar: AppBar(title: const Text('تم العثور على سائق')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) {
          final appError = AppError.from(error);
          return ErrorScreen(
            message: appError.toUserMessage(),
            onRetry: () => ref.refresh(orderTrackingProvider(orderId)),
          );
        },
        data: (snapshot) {
          if (snapshot == null || !snapshot.exists) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final driverId = data['driverId'] as String?;
          final status = data['status'] as String?;

          return FutureBuilder<DocumentSnapshot>(
            future: driverId != null ? FirebaseFirestore.instance.collection('drivers').doc(driverId).get() : null,
            builder: (context, driverSnapshot) {
              final driverData = driverSnapshot.data?.data() as Map<String, dynamic>?;
              final driverName = driverData?['name'] as String? ?? 'السائق';
              final driverPhone = driverData?['phone'] as String? ?? '';
              final vehicle = driverData?['vehicle'] as String? ?? 'غير محدد';

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
                    const SizedBox(height: 24),
                    const Text(
                      'تم قبول طلبك!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('السائق: $driverName', style: const TextStyle(fontSize: 18)),
                            const SizedBox(height: 8),
                            if (driverPhone.isNotEmpty)
                              Text('الهاتف: $driverPhone', style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('المركبة: $vehicle', style: const TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('الحالة: ${status ?? "غير معروف"}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (driverId != null) _buildDriverMap(ref, orderId, data),
                    const SizedBox(height: 16),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.access_time),
                            SizedBox(width: 8),
                            Text('الوقت المتوقع للوصول: 5-10 دقائق', style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        context.go('/track/$orderId');
                      },
                      child: const Text('تتبع السائق'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildDriverMap(WidgetRef ref, String orderId, Map<String, dynamic> orderData) {
    final driverLocationAsync = ref.watch(driverLocationProvider(orderId));

    return Card(
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('موقع السائق', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: driverLocationAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                  child: Text('لا يمكن تحديد موقع السائق حالياً'),
                ),
                data: (driverLocation) {
                  if (driverLocation == null) {
                    return const Center(
                      child: Text('السائق غير متصل حالياً'),
                    );
                  }

                  return _DriverMapWidget(
                    driverLocation: driverLocation,
                    orderData: orderData,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverMapWidget extends StatefulWidget {
  final DriverLocation driverLocation;
  final Map<String, dynamic> orderData;

  const _DriverMapWidget({
    required this.driverLocation,
    required this.orderData,
  });

  @override
  State<_DriverMapWidget> createState() => _DriverMapWidgetState();
}

class _DriverMapWidgetState extends State<_DriverMapWidget> with WidgetsBindingObserver, SafeCameraMixin {
  Set<Marker> _markers = {};
  double _currentZoom = 15.0;

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;
  }

  @override
  void initState() {
    super.initState();
    _updateMarkers();
  }

  @override
  void didUpdateWidget(_DriverMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverLocation.position != widget.driverLocation.position) {
      _updateMarkers();
      _animateToDriver();
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};

    // Driver marker
    markers.add(Marker(
      markerId: const MarkerId('driver'),
      position: widget.driverLocation.position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: 'السائق'),
    ));

    // Pickup marker if available
    final pickup = widget.orderData['pickup'] as Map<String, dynamic>?;
    if (pickup != null) {
      final lat = pickup['lat'] as double?;
      final lng = pickup['lng'] as double?;
      if (lat != null && lng != null) {
        markers.add(Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'نقطة الاستلام',
            snippet: pickup['label'] as String?,
          ),
        ));
      }
    }

    setState(() {
      _markers = markers;
    });
  }

  void _animateToDriver() {
    safeAnimateCamera(
      CameraUpdate.newLatLng(widget.driverLocation.position),
      action: 'animate_to_driver',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        // Update zoom provider
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(currentZoomProvider.notifier).state = _currentZoom;
        });

        final polygons = ref.watch(districtPolygonsProvider);
        final locale = Localizations.localeOf(context);
        final markersAsync = ref.watch(districtMarkersProvider(locale.languageCode));

        return markersAsync.when(
          data: (districtMarkers) => GoogleMap(
            onMapCreated: (controller) {
              onMapCreated(controller);
              scheduleCameraOperation(() => _animateToDriver());
            },
            onCameraMove: _onCameraMove,
            initialCameraPosition: CameraPosition(
              target: widget.driverLocation.position,
              zoom: 15.0,
            ),
            markers: {..._markers, ...districtMarkers},
            polygons: polygons,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
          loading: () => GoogleMap(
            onMapCreated: (controller) {
              onMapCreated(controller);
              scheduleCameraOperation(() => _animateToDriver());
            },
            onCameraMove: _onCameraMove,
            initialCameraPosition: CameraPosition(
              target: widget.driverLocation.position,
              zoom: 15.0,
            ),
            markers: _markers,
            polygons: polygons,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
          error: (error, stack) => GoogleMap(
            onMapCreated: (controller) {
              onMapCreated(controller);
              scheduleCameraOperation(() => _animateToDriver());
            },
            onCameraMove: _onCameraMove,
            initialCameraPosition: CameraPosition(
              target: widget.driverLocation.position,
              zoom: 15.0,
            ),
            markers: _markers,
            polygons: polygons,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapToolbarEnabled: false,
          ),
        );
      },
    );
  }
}
