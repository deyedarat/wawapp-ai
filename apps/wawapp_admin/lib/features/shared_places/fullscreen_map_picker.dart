import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Fullscreen Google Maps picker page with Places search.
/// Returns the selected [LatLng] when confirmed, or null if cancelled.
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          GoogleMap(
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
            markers: _selectedLocation != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
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

          // My location button
          Positioned(
            bottom: _selectedLocation != null ? 120 : 80,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: () {
                // Move to default Nouakchott center
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_defaultCenter, 13),
                );
              },
              child: const Icon(Icons.center_focus_strong),
            ),
          ),
        ],
      ),
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
  /// For better results with Google Places, use the Places API directly.
  Future<void> _performSearch(String query) async {
    try {
      // Use Nominatim for search (free) — focused on Mauritania
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&limit=8&countrycodes=mr&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data
              .map(
                (item) => _SearchResult(
                  name: item['display_name'] as String,
                  location: LatLng(
                    double.parse(item['lat'] as String),
                    double.parse(item['lon'] as String),
                  ),
                ),
              )
              .toList();
          _isSearching = false;
        });
      } else {
        setState(() => _isSearching = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
      debugPrint('Search error: $e');
    }
  }

  Future<void> _reverseGeocode(LatLng position) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?'
        'format=json&lat=${position.latitude}&lon=${position.longitude}&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _selectedAddress = data['display_name'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _selectedLocation = result.location;
      _searchResults = [];
      _searchController.text = result.name;
      _selectedAddress = result.name;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.location, 16),
    );
  }
}

class _SearchResult {
  final String name;
  final LatLng location;

  const _SearchResult({required this.name, required this.location});
}
