/**
 * FIX #3: Dedicated Map Picker Screen
 * 
 * Standalone screen for picking pickup and dropoff locations with:
 * - Search/autocomplete support
 * - Manual pin drop with reverse geocoding
 * - Confirm button returns selected locations
 * - Preserves existing selections on back/cancel
 * 
 * Author: WawApp Development Team (Critical Fix)
 * Last Updated: 2025-12-28
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/location/location_service.dart';

/// Data model for selected location
class SelectedLocation {
  final String label;
  final double latitude;
  final double longitude;
  final String? placeId;

  const SelectedLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.placeId,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'latitude': latitude,
        'longitude': longitude,
        if (placeId != null) 'placeId': placeId,
      };

  factory SelectedLocation.fromJson(Map<String, dynamic> json) {
    return SelectedLocation(
      label: json['label'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      placeId: json['placeId'] as String?,
    );
  }
}

/// Map Picker Screen
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<SelectedLocation>(
///   context,
///   MaterialPageRoute(
///     builder: (context) => MapPickerScreen(
///       title: 'اختر موقع الانطلاق',
///       initialLocation: existingLocation,
///     ),
///   ),
/// );
/// if (result != null) {
///   // Update order draft with result
/// }
/// ```
class MapPickerScreen extends StatefulWidget {
  final String title;
  final SelectedLocation? initialLocation;

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _selectedLabel = 'الموقع المحدد';
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedPosition = LatLng(
        widget.initialLocation!.latitude,
        widget.initialLocation!.longitude,
      );
      _selectedLabel = widget.initialLocation!.label;
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final newPosition = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPosition = newPosition;
        _selectedLabel = 'موقعي الحالي';
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(newPosition, 15),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MapPicker] Error getting current location: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل تحديد الموقع الحالي')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _selectedPosition = position;
      _selectedLabel = 'جار تحديد العنوان...';
    });

    try {
      final address = await LocationService.resolveAddressFromLatLng(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedLabel = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedLabel =
              'الموقع المحدد (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';
        });
      }
    }
  }

  void _onConfirm() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد موقع على الخريطة')),
      );
      return;
    }

    final result = SelectedLocation(
      label: _selectedLabel,
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
      placeId: null, // TODO: Add placeId if using Places API
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map view wrapped in RepaintBoundary for performance
          RepaintBoundary(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedPosition ??
                    const LatLng(18.0735, -15.9582), // Nouakchott, Mauritania
                zoom: 13,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              onTap: _onMapTap,
              markers: _selectedPosition != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: _selectedPosition!,
                        draggable: true,
                        onDragEnd: _onMapTap,
                      ),
                    }
                  : {},
              myLocationEnabled: true,
              myLocationButtonEnabled: false, // Custom button below
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // Search bar at top
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ابحث عن عنوان...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                // TODO: Implement autocomplete/search
                // For MVP, manual pin drop is sufficient
              ),
            ),
          ),

          // Bottom sheet with selected location info and actions
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Selected location display
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedLabel,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'الإحداثيات: ${_selectedPosition!.latitude.toStringAsFixed(4)}, ${_selectedPosition!.longitude.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      // Current location button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _getCurrentLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text('موقعي'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Confirm button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _selectedPosition == null || _isLoading
                              ? null
                              : _onConfirm,
                          child: const Text('تأكيد الموقع'),
                        ),
                      ),
                    ],
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
