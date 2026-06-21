import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../orders/widgets/google_maps_checker.dart';

/// Fullscreen Google Maps picker page with Places search.
/// Returns the selected [LatLng] when confirmed, or null if cancelled.
///
/// Displays existing shared places as fixed blue markers for reference,
/// and lets the user tap to place a red marker for the new/edited location.
class FullscreenMapPicker extends StatefulWidget {
  /// Pass initial location as latlong2.LatLng — we convert internally.
  final dynamic initialLocation;

  const FullscreenMapPicker({super.key, this.initialLocation});

  @override
  State<FullscreenMapPicker> createState() => _FullscreenMapPickerState();
}

class _FullscreenMapPickerState extends State<FullscreenMapPicker> {
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();

  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  String? _selectedAddress;

  /// Existing shared places loaded from Firestore (displayed as fixed markers)
  List<Map<String, dynamic>> _existingPlaces = [];

  // Default: Nouakchott, Mauritania
  static const _defaultCenter = LatLng(18.0735, -15.9582);

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      // Support both google_maps LatLng and latlong2 LatLng
      final loc = widget.initialLocation;
      if (loc is LatLng) {
        _selectedLocation = loc;
      } else {
        // latlong2.LatLng has .latitude and .longitude
        _selectedLocation = LatLng(loc.latitude as double, loc.longitude as double);
      }
    }
    _loadExistingPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Load existing shared places from Firestore to display as reference markers
  Future<void> _loadExistingPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shared_places')
          .where('isActive', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _existingPlaces = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? '',
              'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
              'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
              'category': data['category'] as String? ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading existing places: $e');
    }
  }

  /// Build all markers: existing places (blue, fixed) + selected location (red)
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // 1. Existing shared places as FIXED blue markers (reference only)
    for (final place in _existingPlaces) {
      final lat = place['latitude'] as double;
      final lng = place['longitude'] as double;
      if (lat == 0.0 && lng == 0.0) continue;
      markers.add(
        Marker(
          markerId: MarkerId('place_${place['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: place['name'] as String, snippet: place['category'] as String),
        ),
      );
    }

    // 2. Selected location as a RED marker (user's choice)
    if (_selectedLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: _selectedAddress ?? 'الموقع المحدد'),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (!isGoogleMapsAvailable) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('اختر الموقع على الخريطة'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ),
        body: const GoogleMapsBlockedWidget(title: 'اختر الموقع على الخريطة'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختر الموقع على الخريطة'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_selectedLocation != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _selectedLocation),
                icon: const Icon(Icons.check),
                label: const Text('تأكيد الموقع'),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          SafeGoogleMap(
            googleMap: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? _defaultCenter,
                zoom: _selectedLocation != null ? 16 : 12,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (position) {
                setState(() {
                  _selectedLocation = position;
                  _searchResults = [];
                  _selectedAddress = null;
                });
                _reverseGeocode(position);
              },
              markers: _buildMarkers(),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              // Enable zoom controls for better UX on web
              zoomControlsEnabled: true,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              tiltGesturesEnabled: false,
              rotateGesturesEnabled: false,
              mapToolbarEnabled: false,
              // Fix: Allow scroll-wheel zoom without Ctrl key on web
              webGestureHandling: WebGestureHandling.greedy,
            ),
          ),

          // Search bar at top
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(28),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن مكان...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),

                // Search results dropdown
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: const Center(
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),

                if (!_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(Icons.place, color: Colors.blue),
                          title: Text(
                            result.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                          dense: true,
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Instructions banner
          if (_selectedLocation == null && _searchResults.isEmpty && !_isSearching)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'ابحث أو انقر على الخريطة لتحديد الموقع',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Coordinates card at bottom
          if (_selectedLocation != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Colors.red, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedAddress ?? 'الموقع المحدد',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_selectedLocation!.latitude.toStringAsFixed(6)}, '
                              '${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, _selectedLocation),
                        child: const Text('تأكيد'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // My location / reset button
          Positioned(
            bottom: _selectedLocation != null ? 120 : 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: () {
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_defaultCenter, 13));
              },
              child: const Icon(Icons.center_focus_strong),
            ),
          ),

          // Legend
          Positioned(
            top: 80,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem(BitmapDescriptor.hueRed, 'الموقع المحدد'),
                  const SizedBox(height: 4),
                  _legendItem(BitmapDescriptor.hueAzure, 'أماكن محفوظة'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(double hue, String label) {
    final color = hue == BitmapDescriptor.hueRed
        ? Colors.red
        : hue == BitmapDescriptor.hueAzure
        ? Colors.lightBlue
        : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, color: color, size: 16),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query.trim());
    });
  }

  /// Search using Nominatim (free, no API key needed for search).
  Future<void> _performSearch(String query) async {
    try {
      final results = <_SearchResult>[];

      // 1. Search existing places first
      for (final place in _existingPlaces) {
        final name = place['name'] as String;
        final category = place['category'] as String;
        if (name.contains(query) || category.contains(query)) {
          results.add(
            _SearchResult(name: '⭐ $name', location: LatLng(place['latitude'] as double, place['longitude'] as double)),
          );
        }
      }

      // 2. Search Nominatim
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&limit=8&countrycodes=mr&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        results.addAll(
          data.map(
            (item) => _SearchResult(
              name: item['display_name'] as String,
              location: LatLng(double.parse(item['lat'] as String), double.parse(item['lon'] as String)),
            ),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
      debugPrint('Search error: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    // 1) Check if tapped near an existing shared place (free, no API call)
    final nearbyPlace = _findNearbyExistingPlace(position);
    if (nearbyPlace != null) {
      if (mounted) {
        setState(() {
          _selectedAddress = nearbyPlace['name'] as String;
        });
      }
      return;
    }

    // 2) Fallback to Nominatim reverse geocoding
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        setState(() {
          // Take first two parts for a shorter address
          if (displayName != null && displayName.contains(',')) {
            final parts = displayName.split(',');
            _selectedAddress = parts.length > 2 ? '${parts[0].trim()}, ${parts[1].trim()}' : displayName;
          } else {
            _selectedAddress = displayName;
          }
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  /// Find the nearest existing shared place within ~100m of the tapped position.
  Map<String, dynamic>? _findNearbyExistingPlace(LatLng position) {
    const thresholdDeg = 0.001; // ~111m at equator
    for (final place in _existingPlaces) {
      final lat = place['latitude'] as double;
      final lng = place['longitude'] as double;
      final dLat = (position.latitude - lat).abs();
      final dLng = (position.longitude - lng).abs();
      if (dLat < thresholdDeg && dLng < thresholdDeg) {
        return place;
      }
    }
    return null;
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _selectedLocation = result.location;
      _searchResults = [];
      _searchController.text = result.name;
      _selectedAddress = result.name;
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(result.location, 16));
  }
}

class _SearchResult {
  final String name;
  final LatLng location;

  const _SearchResult({required this.name, required this.location});
}
