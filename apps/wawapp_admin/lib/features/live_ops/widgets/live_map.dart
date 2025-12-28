/**
 * Live Map Widget
 * Displays real-time drivers and orders on a map
 */

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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

class _LiveMapState extends State<LiveMap> {
  final MapController _mapController = MapController();
  
  // Default center: Nouakchott, Mauritania
  static const LatLng _defaultCenter = LatLng(18.0735, -15.9582);
  static const double _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _centerMapOnData();
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.drivers != oldWidget.drivers || 
        widget.orders != oldWidget.orders) {
      _centerMapOnData();
    }
  }

  void _centerMapOnData() {
    if (widget.drivers.isEmpty && widget.orders.isEmpty) return;

    // Calculate bounds from all markers
    final allLocations = <LatLng>[
      ...widget.drivers.map((d) => d.location),
      ...widget.orders.map((o) => o.pickupLocation),
      ...widget.orders.map((o) => o.dropoffLocation),
    ];

    if (allLocations.isEmpty) return;

    // Simple center calculation (average of all points)
    double sumLat = 0;
    double sumLng = 0;
    for (final loc in allLocations) {
      sumLat += loc.latitude;
      sumLng += loc.longitude;
    }
    final center = LatLng(
      sumLat / allLocations.length,
      sumLng / allLocations.length,
    );

    // Move map to center
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mapController.move(center, _defaultZoom);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _defaultCenter,
        initialZoom: _defaultZoom,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        // Tile layer (OpenStreetMap)
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.wawapp.admin',
        ),
        
        // Driver markers
        MarkerLayer(
          markers: widget.drivers.map((driver) {
            return Marker(
              point: driver.location,
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => widget.onDriverTap?.call(driver),
                child: _buildDriverMarker(driver),
              ),
            );
          }).toList(),
        ),

        // Order pickup markers
        MarkerLayer(
          markers: widget.orders.map((order) {
            return Marker(
              point: order.pickupLocation,
              width: 32,
              height: 32,
              child: GestureDetector(
                onTap: () => widget.onOrderTap?.call(order),
                child: _buildOrderPickupMarker(order),
              ),
            );
          }).toList(),
        ),

        // Order dropoff markers
        MarkerLayer(
          markers: widget.orders.map((order) {
            return Marker(
              point: order.dropoffLocation,
              width: 32,
              height: 32,
              child: _buildOrderDropoffMarker(order),
            );
          }).toList(),
        ),

        // Lines connecting pickup to dropoff
        PolylineLayer(
          polylines: widget.orders.map((order) {
            return Polyline(
              points: [order.pickupLocation, order.dropoffLocation],
              strokeWidth: 2.0,
              color: _parseColor(order.statusColor).withOpacity(0.5),
              isDotted: true,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDriverMarker(LiveDriverMarker driver) {
    final color = _parseColor(driver.statusColor);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer circle (glow effect)
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
        ),
        // Inner circle (main marker)
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.local_shipping,
            size: 16,
            color: Colors.white,
          ),
        ),
        // Anomaly indicator (if driver has stuck order)
        if (driver.activeOrderId != null)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AdminAppColors.warningLight,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrderPickupMarker(LiveOrderMarker order) {
    final color = _parseColor(order.statusColor);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main marker
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.place,
            size: 20,
            color: Colors.white,
          ),
        ),
        // Anomaly indicator
        if (order.isAnomalous())
          Positioned(
            top: 0,
            right: 0,
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

  Widget _buildOrderDropoffMarker(LiveOrderMarker order) {
    final color = _parseColor(order.statusColor);
    
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.7),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.flag,
        size: 16,
        color: Colors.white,
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}
