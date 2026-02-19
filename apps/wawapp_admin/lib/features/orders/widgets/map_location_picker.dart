import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Selected location data model
class LocationData {
  final String address;
  final double latitude;
  final double longitude;

  const LocationData({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}

/// Interactive map widget for picking a location
class MapLocationPicker extends StatefulWidget {
  final String title;
  final LocationData? initialLocation;

  const MapLocationPicker({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  late MapController _mapController;
  LatLng? _selectedPosition;
  String _selectedAddress = 'اضغط على الخريطة لتحديد الموقع';
  bool _isLoadingAddress = false;

  // Default center: Nouakchott, Mauritania
  static const LatLng _defaultCenter = LatLng(18.0735, -15.9582);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    if (widget.initialLocation != null) {
      _selectedPosition = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _selectedAddress = widget.initialLocation!.address;
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Reverse geocode using Nominatim (OpenStreetMap)
  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'WawApp-Admin/1.0',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'عنوان غير معروف';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }

    return 'الموقع: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  /// Handle map tap
  Future<void> _onMapTap(TapPosition tapPosition, LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _selectedAddress = 'جار تحديد العنوان...';
      _isLoadingAddress = true;
    });

    // Move map to selected position
    _mapController.move(position, _mapController.camera.zoom);

    // Get address
    final address = await _getAddressFromLatLng(position.latitude, position.longitude);

    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    }
  }

  /// Confirm selection
  void _confirmSelection() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الرجاء تحديد موقع على الخريطة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = LocationData(
      address: _selectedAddress,
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition ?? _defaultCenter,
              initialZoom: 15.0, // Increased zoom for better detail
              minZoom: 3.0,
              maxZoom: 19.0,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
              ),
            ),
            children: [
              // High-quality tile layer with better provider
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'], // Load balancing
                userAgentPackageName: 'com.wawapp.admin',
                maxZoom: 19,
                minZoom: 3,
                // Better quality settings
                tileSize: 256,
                retinaMode: true, // High DPI support
                errorImage: const AssetImage('assets/icons/map_error.png'),
                // Performance optimization
                keepBuffer: 2,
                panBuffer: 1,
                // Better rendering
                tileProvider: NetworkTileProvider(),
              ),
              // Marker layer with enhanced marker
              if (_selectedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPosition!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.topCenter,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Shadow
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                          // Marker icon
                          const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 50,
                            shadows: [
                              Shadow(
                                color: Colors.white,
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Zoom controls
          Positioned(
            right: 16,
            top: 80,
            child: Column(
              children: [
                // Zoom in button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom + 1,
                      );
                    },
                    tooltip: 'تكبير',
                  ),
                ),
                const SizedBox(height: 8),
                // Zoom out button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(
                        _mapController.camera.center,
                        currentZoom - 1,
                      );
                    },
                    tooltip: 'تصغير',
                  ),
                ),
                const SizedBox(height: 8),
                // Current location button
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: () {
                      if (_selectedPosition != null) {
                        _mapController.move(_selectedPosition!, 16);
                      }
                    },
                    tooltip: 'الموقع المحدد',
                  ),
                ),
              ],
            ),
          ),

          // Bottom info card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Address display
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF00C853),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الموقع المحدد',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _selectedAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),

                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الإحداثيات: ${_selectedPosition!.latitude.toStringAsFixed(4)}, ${_selectedPosition!.longitude.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Confirm button
                  ElevatedButton(
                    onPressed: _isLoadingAddress ? null : _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'تأكيد الموقع',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
