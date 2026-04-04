/**
 * Live Map Widget – IMPROVED
  *
   * Changes from original:
    *  1. Always renders the base tile map; drivers/orders are optional overlays.
     *  2. Tile URL uses the OSM sub-domain mirror (a/b/c) for load-balancing and
      *     better CORS handling on Flutter Web.
       *  3. Added in-map zoom +/- floating buttons.
        *  4. Added a compact map legend (driver colours + order icons).
         *  5. Animated "pulse" ring around online driver markers.
          *  6. "Fit all markers" button that auto-adjusts the camera.
           *  7. Route polylines are now solid for active orders, dashed for others.
            */

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/colors.dart';
import '../models/live_driver_marker.dart';
import '../models/live_order_marker.dart';

class LiveMap extends StatefulWidget {
    final List<LiveDriverMarker> drivers;
    final List<LiveOrderMarker> orders;
    final Function(LiveDriverMarker)? onDriverTap;
    final Function(LiveOrderMarker)? onOrderTap;

    const LiveMap({
          super.key,
          required this.drivers,
          required this.orders,
          this.onDriverTap,
          this.onOrderTap,
    });

    @override
    State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> with TickerProviderStateMixin {
    final MapController _mapController = MapController();
    bool _legendExpanded = false;
    String? _selectedDriverId;
    String? _selectedOrderId;
    double _currentZoom = _defaultZoom;

    static const LatLng _defaultCenter = LatLng(18.0735, -15.9582);
    static const double _defaultZoom = 12.0;

    late AnimationController _pulseController;
    late Animation<double> _pulseAnimation;

    @override
    void initState() {
          super.initState();
          _pulseController = AnimationController(
                  vsync: this,
                  duration: const Duration(seconds: 2),
                )..repeat();
          _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
                );
          _mapController.mapEventStream.listen((event) {
                  if (event is MapEventMove || event is MapEventRotate) {
                          setState(() => _currentZoom = _mapController.camera.zoom);
                  }
                });
          WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers());
    }

    @override
    void didUpdateWidget(LiveMap oldWidget) {
          super.didUpdateWidget(oldWidget);
          if (widget.drivers != oldWidget.drivers ||
                      widget.orders != oldWidget.orders) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _fitMarkers());
          }
    }

    @override
    void dispose() {
          _pulseController.dispose();
          super.dispose();
    }

    void _fitMarkers() {
          final allLocations = <LatLng>[
                  ...widget.drivers.map((d) => d.location),
                  ...widget.orders.map((o) => o.pickupLocation),
                  ...widget.orders.map((o) => o.dropoffLocation),
                ];
          if (allLocations.isEmpty) return;
          if (allLocations.length == 1) {
                  _mapController.move(allLocations.first, _defaultZoom);
                  return;
          }
          double minLat = allLocations.first.latitude;
          double maxLat = allLocations.first.latitude;
          double minLng = allLocations.first.longitude;
          double maxLng = allLocations.first.longitude;
          for (final loc in allLocations) {
                  if (loc.latitude < minLat) minLat = loc.latitude;
                  if (loc.latitude > maxLat) maxLat = loc.latitude;
                  if (loc.longitude < minLng) minLng = loc.longitude;
                  if (loc.longitude > maxLng) maxLng = loc.longitude;
          }
          final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
          final spread = (maxLat - minLat) > (maxLng - minLng)
                    ? (maxLat - minLat)
                    : (maxLng - minLng);
          double zoom = _defaultZoom;
          if (spread > 5) zoom = 8;
          else if (spread > 2) zoom = 10;
          else if (spread > 0.5) zoom = 12;
          else if (spread > 0.1) zoom = 13;
          else zoom = 14;
          _mapController.move(center, zoom);
    }

    void _zoomIn() =>
            _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);

    void _zoomOut() =>
            _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);

    void _resetToDefault() => _mapController.move(_defaultCenter, _defaultZoom);

    List<LiveDriverMarker> _getVisibleDrivers() {
          if (_currentZoom < 10) {
                  return widget.drivers.where((d) => d.isOnline && !d.isBlocked).toList();
          } else if (_currentZoom < 12) {
                  return widget.drivers.where((d) =>
                            (d.isOnline && !d.isBlocked) || d.activeOrderId != null
                          ).toList();
          }
          return widget.drivers;
    }

    List<LiveOrderMarker> _getVisibleOrders() {
          if (_currentZoom < 11) {
                  return widget.orders.where((o) => o.isActive).toList();
          }
          return widget.orders;
    }

    @override
    Widget build(BuildContext context) {
          return Stack(
                  children: [
                            FlutterMap(
                                        mapController: _mapController,
                                        options: MapOptions(
                                                      initialCenter: _defaultCenter,
                                                      initialZoom: _defaultZoom,
                                                      minZoom: 4.0,
                                                      maxZoom: 19.0,
                                                      interactionOptions: const InteractionOptions(
                                                                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                                                                    ),
                                                    ),
                                        children: [
                                                      TileLayer(
                                                                      // Carto Voyager – clean, professional, no clutter
                                                                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                                                      subdomains: const ['a', 'b', 'c', 'd'],
                                                                      userAgentPackageName: 'com.wawapp.admin',
                                                                      maxZoom: 20,
                                                                      minZoom: 2,
                                                                      retinaMode: true,
                                                                      keepBuffer: 4,
                                                                      panBuffer: 2,
                                                                      errorTileCallback: (tile, error, stack) {},
                                                                    ),
                                                      PolylineLayer(
                                                                      polylines: widget.orders.map((order) {
                                                                                        final color = _parseColor(order.statusColor);
                                                                                        final isActive = order.isActive;
                                                                                        return Polyline(
                                                                                                            points: [order.pickupLocation, order.dropoffLocation],
                                                                                                            strokeWidth: isActive ? 3.0 : 1.5,
                                                                                                            color: color.withOpacity(isActive ? 0.7 : 0.35),
                                                                                                            isDotted: !isActive,
                                                                                                          );
                                                                      }).toList(),
                                                                    ),
                                                      MarkerLayer(
                                                                      markers: _getVisibleOrders().map((order) => Marker(
                                                                                        point: order.dropoffLocation,
                                                                                        width: 28,
                                                                                        height: 28,
                                                                                        child: _buildDropoffMarker(order),
                                                                                      )).toList(),
                                                                    ),
                                                      MarkerClusterLayerWidget(
                                                                      options: MarkerClusterLayerOptions(
                                                                                        maxClusterRadius: 60,
                                                                                        size: const Size(45, 45),
                                                                                        markers: _getVisibleOrders().map((order) => Marker(
                                                                                                            point: order.pickupLocation,
                                                                                                            width: 34,
                                                                                                            height: 34,
                                                                                                            child: GestureDetector(
                                                                                                                          onTap: () {
                                                                                                                                        setState(() {
                                                                                                                                                      _selectedOrderId = order.orderId;
                                                                                                                                                      _selectedDriverId = null;
                                                                                                                                                    });
                                                                                                                                        widget.onOrderTap?.call(order);
                                                                                                                                      },
                                                                                                                          child: _HoverScaleMarker(
                                                                                                                                        child: _buildPickupMarker(order),
                                                                                                                                      ),
                                                                                                                        ),
                                                                                                          )).toList(),
                                                                                        builder: (context, markers) {
                                                                                                      return Container(
                                                                                                                    decoration: BoxDecoration(
                                                                                                                                  color: Colors.blue.withOpacity(0.9),
                                                                                                                                  shape: BoxShape.circle,
                                                                                                                                  border: Border.all(color: Colors.white, width: 2),
                                                                                                                                ),
                                                                                                                    child: Center(
                                                                                                                                  child: Text(
                                                                                                                                                '${markers.length}',
                                                                                                                                                style: const TextStyle(
                                                                                                                                                              color: Colors.white,
                                                                                                                                                              fontWeight: FontWeight.bold,
                                                                                                                                                              fontSize: 12,
                                                                                                                                                            ),
                                                                                                                                              ),
                                                                                                                                ),
                                                                                                                  );
                                                                                        },
                                                                                      ),
                                                                    ),
                                                      MarkerClusterLayerWidget(
                                                                      options: MarkerClusterLayerOptions(
                                                                                        maxClusterRadius: 80,
                                                                                        size: const Size(50, 50),
                                                                                        markers: _getVisibleDrivers().map((driver) => Marker(
                                                                                                            point: driver.location,
                                                                                                            width: 48,
                                                                                                            height: 48,
                                                                                                            child: GestureDetector(
                                                                                                                          onTap: () {
                                                                                                                                        setState(() {
                                                                                                                                                      _selectedDriverId = driver.driverId;
                                                                                                                                                      _selectedOrderId = null;
                                                                                                                                                    });
                                                                                                                                        widget.onDriverTap?.call(driver);
                                                                                                                                      },
                                                                                                                          child: _HoverScaleMarker(
                                                                                                                                        child: driver.isOnline && !driver.isBlocked
                                                                                                                                            ? _buildOnlineDriverMarker(driver)
                                                                                                                                            : _buildDriverMarkerCore(driver),
                                                                                                                                      ),
                                                                                                                        ),
                                                                                                          )).toList(),
                                                                                        builder: (context, markers) {
                                                                                                      return Container(
                                                                                                                    decoration: BoxDecoration(
                                                                                                                                  color: AdminAppColors.primaryLight.withOpacity(0.9),
                                                                                                                                  shape: BoxShape.circle,
                                                                                                                                  border: Border.all(color: Colors.white, width: 2),
                                                                                                                                ),
                                                                                                                    child: Center(
                                                                                                                                  child: Text(
                                                                                                                                                '${markers.length}',
                                                                                                                                                style: const TextStyle(
                                                                                                                                                              color: Colors.white,
                                                                                                                                                              fontWeight: FontWeight.bold,
                                                                                                                                                              fontSize: 14,
                                                                                                                                                            ),
                                                                                                                                              ),
                                                                                                                                ),
                                                                                                                  );
                                                                                        },
                                                                                      ),
                                                                    ),
                                                      RichAttributionWidget(
                                                                      animationConfig: const ScaleRAWA(),
                                                                      attributions: [
                                                                                        TextSourceAttribution('© Carto', onTap: () {}),
                                                                                        TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
                                                                                      ],
                                                                    ),
                                                    ],
                                      ),
                            if (_selectedDriverId != null || _selectedOrderId != null)
                              Positioned.fill(
                                            child: GestureDetector(
                                                            onTap: () => setState(() {
                                                                              _selectedDriverId = null;
                                                                              _selectedOrderId = null;
                                                                            }),
                                                            child: Container(
                                                                              color: Colors.black.withOpacity(0.3),
                                                                            ),
                                                          ),
                                          ),
                            Positioned(
                                        top: 12,
                                        right: 12,
                                        child: Column(
                                                      children: [
                                                                      _mapButton(Icons.add, _zoomIn, tooltip: 'تكبير'),
                                                                      const SizedBox(height: 4),
                                                                      _mapButton(Icons.remove, _zoomOut, tooltip: 'تصغير'),
                                                                      const SizedBox(height: 8),
                                                                      _mapButton(Icons.my_location, _resetToDefault, tooltip: 'الموقع الافتراضي'),
                                                                      const SizedBox(height: 4),
                                                                      _mapButton(Icons.fit_screen, _fitMarkers, tooltip: 'إظهار كل العناصر'),
                                                                    ],
                                                    ),
                                      ),
                            Positioned(
                                        bottom: 12,
                                        right: 12,
                                        child: _buildCollapsibleLegend(context),
                                      ),
                            if (widget.drivers.isEmpty && widget.orders.isEmpty)
                              Positioned(
                                            top: 12,
                                            left: 0,
                                            right: 0,
                                            child: Center(
                                                            child: Container(
                                                                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                                              decoration: BoxDecoration(
                                                                                                  color: Colors.black.withOpacity(0.6),
                                                                                                  borderRadius: BorderRadius.circular(24),
                                                                                                ),
                                                                              child: const Row(
                                                                                                  mainAxisSize: MainAxisSize.min,
                                                                                                  children: [
                                                                                                                        Icon(Icons.info_outline, color: Colors.white, size: 18),
                                                                                                                        SizedBox(width: 8),
                                                                                                                        Text(
                                                                                                                                                'لا يوجد سائقون أو طلبات نشطة حالياً',
                                                                                                                                                style: TextStyle(color: Colors.white, fontSize: 13),
                                                                                                                                              ),
                                                                                                                      ],
                                                                                                ),
                                                                            ),
                                                          ),
                                          ),
                          ],
                );
    }

    Widget _buildOnlineDriverMarker(LiveDriverMarker driver) {
          return AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, child) {
                            final ring = _pulseAnimation.value;
                            return Stack(
                                        alignment: Alignment.center,
                                        children: [
                                                      Opacity(
                                                                      opacity: (1 - ring).clamp(0.0, 1.0),
                                                                      child: Container(
                                                                                        width: 48 * ring,
                                                                                        height: 48 * ring,
                                                                                        decoration: BoxDecoration(
                                                                                                            shape: BoxShape.circle,
                                                                                                            color: AdminAppColors.successLight.withOpacity(0.35),
                                                                                                          ),
                                                                                      ),
                                                                    ),
                                                      child!,
                                                    ],
                                      );
                  },
                  child: _buildDriverMarkerCore(driver),
                );
    }

    Widget _buildDriverMarkerCore(LiveDriverMarker driver) {
          final color = _parseColor(driver.statusColor);
          final isSelected = _selectedDriverId == driver.driverId;
          return Stack(
                  alignment: Alignment.center,
                  children: [
                            Container(
                                        width: isSelected ? 36 : 30,
                                        height: isSelected ? 36 : 30,
                                        decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: color,
                                                      border: Border.all(
                                                                      color: isSelected ? Colors.yellow : Colors.white,
                                                                      width: isSelected ? 3.5 : 2.5,
                                                                    ),
                                                      boxShadow: [
                                                                      BoxShadow(
                                                                                        color: color.withOpacity(isSelected ? 0.8 : 0.5),
                                                                                        blurRadius: isSelected ? 12 : 6,
                                                                                        spreadRadius: isSelected ? 3 : 1,
                                                                                        offset: const Offset(0, 2),
                                                                                      ),
                                                                    ],
                                                    ),
                                        child: Icon(Icons.directions_car, size: isSelected ? 20 : 16, color: Colors.white),
                                      ),
                            if (driver.activeOrderId != null)
                              Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                                            width: 10,
                                                            height: 10,
                                                            decoration: BoxDecoration(
                                                                              shape: BoxShape.circle,
                                                                              color: Colors.orange,
                                                                              border: Border.all(color: Colors.white, width: 1.5),
                                                                            ),
                                                          ),
                                          ),
                          ],
                );
    }

    Widget _buildPickupMarker(LiveOrderMarker order) {
          final color = _parseColor(order.statusColor);
          return Stack(
                  alignment: Alignment.center,
                  children: [
                            Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: color,
                                                      border: Border.all(color: Colors.white, width: 2),
                                                      boxShadow: [
                                                                      BoxShadow(
                                                                                        color: Colors.black.withOpacity(0.25),
                                                                                        blurRadius: 5,
                                                                                        offset: const Offset(0, 2),
                                                                                      ),
                                                                    ],
                                                    ),
                                        child: const Icon(Icons.place, size: 20, color: Colors.white),
                                      ),
                            if (order.isAnomalous())
                              Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                                            width: 10,
                                                            height: 10,
                                                            decoration: BoxDecoration(
                                                                              shape: BoxShape.circle,
                                                                              color: AdminAppColors.errorLight,
                                                                              border: Border.all(color: Colors.white, width: 1),
                                                                            ),
                                                          ),
                                          ),
                          ],
                );
    }

    Widget _buildDropoffMarker(LiveOrderMarker order) {
          final color = _parseColor(order.statusColor);
          return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.6),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                                        BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                      ],
                          ),
                  child: const Icon(Icons.flag, size: 14, color: Colors.white),
                );
    }

    Widget _mapButton(IconData icon, VoidCallback onPressed, {String tooltip = ''}) {
          return Tooltip(
                  message: tooltip,
                  child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            elevation: 2,
                            child: InkWell(
                                        onTap: onPressed,
                                        borderRadius: BorderRadius.circular(6),
                                        child: SizedBox(
                                                      width: 36,
                                                      height: 36,
                                                      child: Icon(icon, size: 20, color: Colors.grey[700]),
                                                    ),
                                      ),
                          ),
                );
    }

    Widget _buildCollapsibleLegend(BuildContext context) {
          return Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                            if (!_legendExpanded)
                              Material(
                                            color: Colors.white.withOpacity(0.9),
                                            borderRadius: BorderRadius.circular(8),
                                            elevation: 3,
                                            child: IconButton(
                                                            icon: const Icon(Icons.info_outline, size: 20),
                                                            tooltip: 'إظهار دليل الرموز',
                                                            onPressed: () => setState(() => _legendExpanded = true),
                                                          ),
                                          ),
                            if (_legendExpanded)
                              Material(
                                            color: Colors.white.withOpacity(0.95),
                                            borderRadius: BorderRadius.circular(10),
                                            elevation: 3,
                                            child: Container(
                                                            constraints: const BoxConstraints(maxWidth: 200),
                                                            padding: const EdgeInsets.all(12),
                                                            child: Column(
                                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                                              mainAxisSize: MainAxisSize.min,
                                                                              children: [
                                                                                                  Row(
                                                                                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                                                                    children: [
                                                                                                                                  Text(
                                                                                                                                                'دليل الرموز',
                                                                                                                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                                                                                                                              fontWeight: FontWeight.bold,
                                                                                                                                                              color: Colors.grey[700],
                                                                                                                                                            ),
                                                                                                                                              ),
                                                                                                                                  IconButton(
                                                                                                                                                icon: const Icon(Icons.close, size: 18),
                                                                                                                                                padding: EdgeInsets.zero,
                                                                                                                                                constraints: const BoxConstraints(),
                                                                                                                                                onPressed: () => setState(() => _legendExpanded = false),
                                                                                                                                              ),
                                                                                                                                ],
                                                                                                                  ),
                                                                                                  const SizedBox(height: 6),
                                                                                                  _legendRow(color: const Color(0xFF00704A), icon: Icons.directions_car, label: 'سائق متصل'),
                                                                                                  _legendRow(color: const Color(0xFF6C757D), icon: Icons.directions_car, label: 'سائق غير متصل'),
                                                                                                  _legendRow(color: const Color(0xFFC1272D), icon: Icons.directions_car, label: 'سائق محظور'),
                                                                                                  const Divider(height: 10),
                                                                                                  _legendRow(color: Colors.blue, icon: Icons.place, label: 'نقطة الاستلام'),
                                                                                                  _legendRow(color: Colors.orange, icon: Icons.flag, label: 'نقطة التسليم'),
                                                                                                ],
                                                                            ),
                                                          ),
                                          ),
                          ],
                );
    }

    Widget _legendRow({required Color color, required IconData icon, required String label}) {
          return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                        Icon(icon, size: 14, color: color),
                                        const SizedBox(width: 6),
                                        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                      ],
                          ),
                );
    }

    Color _parseColor(String hexColor) {
          try {
                  return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
          } catch (_) {
                  return Colors.grey;
          }
    }
}

class _HoverScaleMarker extends StatefulWidget {
    final Widget child;
    const _HoverScaleMarker({required this.child});

    @override
    State<_HoverScaleMarker> createState() => _HoverScaleMarkerState();
}

class _HoverScaleMarkerState extends State<_HoverScaleMarker> {
    bool _isHovering = false;

    @override
    Widget build(BuildContext context) {
          return MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: AnimatedScale(
                            scale: _isHovering ? 1.15 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOut,
                            child: widget.child,
                          ),
                );
    }
}
