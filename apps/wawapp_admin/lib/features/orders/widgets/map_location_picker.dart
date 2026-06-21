import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'google_maps_checker.dart';

// ============================================================================
// Data Models
// ============================================================================

class LocationData {
  final String address;
  final double latitude;
  final double longitude;

  const LocationData({required this.address, required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {'address': address, 'latitude': latitude, 'longitude': longitude};
}

class _SearchResult {
  final String displayName;
  final LatLng position;
  final String type;

  const _SearchResult(this.displayName, this.position, this.type);
}

// ============================================================================
// Widget
// ============================================================================

const _kGreen = Color(0xFF00C853);

class MapLocationPicker extends StatefulWidget {
  final String title;
  final LocationData? initialLocation;

  const MapLocationPicker({super.key, required this.title, this.initialLocation});

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _selectedAddress = 'اضغط على الخريطة لتحديد الموقع';
  bool _isLoadingAddress = false;
  bool _isSearching = false;
  List<_SearchResult> _searchResults = [];
  List<Map<String, dynamic>> _savedLocations = [];
  List<Map<String, dynamic>> _sharedPlaces = [];
  Timer? _searchDebounce;
  final _searchController = TextEditingController();

  static const LatLng _defaultCenter = LatLng(18.0832, -15.9741);

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedPosition = LatLng(widget.initialLocation!.latitude, widget.initialLocation!.longitude);
      _selectedAddress = widget.initialLocation!.address;
    }
    _loadSavedLocations();
    _loadSharedPlaces();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance.collection('admin_saved_locations').doc(user.uid).get();
      if (doc.exists && doc.data()?['locations'] != null) {
        setState(() {
          _savedLocations = List<Map<String, dynamic>>.from(doc.data()!['locations']);
        });
      }
    } catch (e) {
      debugPrint('Error loading saved locations: $e');
    }
  }

  Future<void> _loadSharedPlaces() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('shared_places')
          .where('isActive', isEqualTo: true)
          .get();
      if (mounted) {
        setState(() {
          _sharedPlaces = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'name': data['name'] as String? ?? '',
              'address': data['address'] as String? ?? '',
              'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
              'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
              'category': data['category'] as String? ?? '',
            };
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading shared places: $e');
    }
  }

  Future<void> _saveCurrentLocation() async {
    if (_selectedPosition == null) return;
    final nameController = TextEditingController(text: 'موقع ${_savedLocations.length + 1}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حفظ الموقع'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'اسم الموقع', hintText: 'مثال: مكتب المبيعات'),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'User not authenticated';
      final newLoc = {
        'name': nameController.text.trim(),
        'address': _selectedAddress,
        'latitude': _selectedPosition!.latitude,
        'longitude': _selectedPosition!.longitude,
        'savedAt': FieldValue.serverTimestamp(),
      };
      final updated = [..._savedLocations, newLoc];
      if (updated.length > 10) updated.removeAt(0);
      await FirebaseFirestore.instance.collection('admin_saved_locations').doc(user.uid).set({
        'locations': updated,
      }, SetOptions(merge: true));
      setState(() => _savedLocations = updated);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الموقع بنجاح'), backgroundColor: _kGreen));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في حفظ الموقع: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showSavedLocations() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'المواقع المحفوظة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            if (_savedLocations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'لا توجد مواقع محفوظة',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _savedLocations.length,
                  itemBuilder: (_, index) {
                    final loc = _savedLocations[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: _kGreen,
                        child: Icon(Icons.bookmark, color: Colors.white, size: 20),
                      ),
                      title: Text(loc['name'] as String),
                      subtitle: Text(loc['address'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(ctx);
                        final pos = LatLng(loc['latitude'] as double, loc['longitude'] as double);
                        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
                        setState(() {
                          _selectedPosition = pos;
                          _selectedAddress = loc['address'] as String;
                        });
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Google Maps API key (same as in index.html for web Google Maps)
  static const _mapsApiKey = 'AIzaSyDF_TYfDGqpoZtYLSYBFvjAPva6Qp3S6Bs';

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    // Try Google Geocoding API first (better POI names in Arabic)
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?latlng=$lat,$lng&key=$_mapsApiKey&language=ar',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          // Look for POI / establishment name first
          for (final result in results) {
            final types = (result['types'] as List<dynamic>?)?.cast<String>() ?? [];
            if (types.any(
              (t) => ['point_of_interest', 'establishment', 'premise', 'store', 'shopping_mall'].contains(t),
            )) {
              final name = result['formatted_address'] as String?;
              if (name != null && name.isNotEmpty) {
                // Return first part (the POI name) before comma
                return name.split(',').first.trim();
              }
            }
          }
          // Fallback: use first result, shortened to 2 parts
          final firstAddress = results[0]['formatted_address'] as String?;
          if (firstAddress != null && firstAddress.isNotEmpty) {
            final parts = firstAddress.split(',');
            if (parts.length > 2) {
              return '${parts[0].trim()}, ${parts[1].trim()}';
            }
            return firstAddress;
          }
        }
      }
    } catch (e) {
      debugPrint('Google Geocoding error, falling back to Nominatim: $e');
    }

    // Fallback: Nominatim (free, no quota)
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',');
          if (parts.length > 2) {
            return '${parts[0].trim()}, ${parts[1].trim()}';
          }
          return displayName;
        }
        return 'عنوان غير معروف';
      }
    } catch (e) {
      debugPrint('Nominatim error: $e');
    }
    return 'الموقع: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _onMapTap(LatLng position) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedPosition = position;
      _selectedAddress = 'جار تحديد العنوان...';
      _isLoadingAddress = true;
    });

    // Check if tapped near a shared place
    final nearbySharedPlace = _findNearbySharedPlace(position, 0.0015);

    String address;
    if (nearbySharedPlace != null) {
      address = nearbySharedPlace['name'] as String;
    } else {
      address = await _getAddressFromLatLng(position.latitude, position.longitude);
    }

    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    }
  }

  Map<String, dynamic>? _findNearbySharedPlace(LatLng position, double thresholdDeg) {
    for (final place in _sharedPlaces) {
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

  void _confirmSelection() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء تحديد موقع على الخريطة'), backgroundColor: Colors.red));
      return;
    }
    Navigator.of(context).pop(
      LocationData(
        address: _selectedAddress,
        latitude: _selectedPosition!.latitude,
        longitude: _selectedPosition!.longitude,
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = <_SearchResult>[];
    final qAr = query;

    // 1. Search shared places
    for (final place in _sharedPlaces) {
      final name = place['name'] as String;
      final address = place['address'] as String;
      final category = place['category'] as String;
      if (name.contains(qAr) || address.contains(qAr) || category.contains(qAr)) {
        results.add(
          _SearchResult('⭐ $name', LatLng(place['latitude'] as double, place['longitude'] as double), 'shared'),
        );
      }
    }

    // 2. Search saved locations
    for (final saved in _savedLocations) {
      final name = saved['name'] as String;
      final address = saved['address'] as String;
      if (name.contains(qAr) || address.contains(qAr)) {
        results.add(
          _SearchResult('📌 $name', LatLng(saved['latitude'] as double, saved['longitude'] as double), 'saved'),
        );
      }
    }

    // 3. If not enough results, use Nominatim
    if (results.length < 3) {
      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?'
          'q=${Uri.encodeComponent(query)}&'
          'format=json&limit=5&countrycodes=mr&accept-language=ar&'
          'bounded=1&viewbox=-16.05,18.15,-15.85,18.00',
        );
        final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          results.addAll(
            data.map(
              (item) => _SearchResult(
                item['display_name'] as String,
                LatLng(double.parse(item['lat'] as String), double.parse(item['lon'] as String)),
                'nominatim',
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Nominatim search error: $e');
      }
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Selected position marker
    if (_selectedPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: _selectedAddress),
        ),
      );
    }

    // Shared places markers
    for (final place in _sharedPlaces) {
      final lat = place['latitude'] as double;
      final lng = place['longitude'] as double;
      if (lat == 0 && lng == 0) continue;
      markers.add(
        Marker(
          markerId: MarkerId('shared_${place['id']}'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: place['name'] as String, snippet: place['category'] as String),
          onTap: () {
            final pos = LatLng(lat, lng);
            setState(() {
              _selectedPosition = pos;
              _selectedAddress = place['name'] as String;
              _isLoadingAddress = false;
            });
          },
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (!isGoogleMapsAvailable) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title), backgroundColor: _kGreen, foregroundColor: Colors.white),
        body: GoogleMapsBlockedWidget(title: widget.title),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showSavedLocations,
        backgroundColor: _kGreen,
        child: Badge(
          label: Text('${_savedLocations.length}'),
          isLabelVisible: _savedLocations.isNotEmpty,
          child: const Icon(Icons.bookmarks, color: Colors.white),
        ),
      ),
      appBar: AppBar(title: Text(widget.title), backgroundColor: _kGreen, foregroundColor: Colors.white),
      body: Stack(
        children: [
          // ── Google Map ──
          Positioned.fill(
            child: SafeGoogleMap(
              googleMap: GoogleMap(
                initialCameraPosition: CameraPosition(target: _selectedPosition ?? _defaultCenter, zoom: 13.0),
                onMapCreated: (controller) => _mapController = controller,
                onTap: _onMapTap,
                onLongPress: _onMapTap,
                markers: _buildMarkers(),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                mapToolbarEnabled: false,
                mapType: MapType.normal,
                // Fix: Allow scroll-wheel zoom without Ctrl key on web
                webGestureHandling: WebGestureHandling.greedy,
              ),
            ),
          ),

          // ── Search bar ──
          Positioned(
            top: 12,
            left: 60,
            right: 60,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن موقع...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                      prefixIcon: const Icon(Icons.search, size: 20, color: _kGreen),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                    ),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 12),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                        _performSearch(value);
                      });
                    },
                    onSubmitted: _performSearch,
                  ),
                ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final r = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            r.type == 'shared'
                                ? Icons.star
                                : r.type == 'saved'
                                ? Icons.bookmark
                                : Icons.location_on,
                            color: r.type == 'shared'
                                ? Colors.orange
                                : r.type == 'saved'
                                ? _kGreen
                                : Colors.blue,
                            size: 20,
                          ),
                          title: Text(
                            r.displayName,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            _mapController?.animateCamera(CameraUpdate.newLatLngZoom(r.position, 16));
                            setState(() {
                              _selectedPosition = r.position;
                              _selectedAddress = r.displayName;
                              _searchResults = [];
                              _isLoadingAddress = false;
                            });
                            _searchController.clear();
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Zoom controls ──
          Positioned(
            right: 12,
            top: 70,
            child: Column(
              children: [
                _zoomButton(Icons.add, 'تكبير', () {
                  _mapController?.animateCamera(CameraUpdate.zoomIn());
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.remove, 'تصغير', () {
                  _mapController?.animateCamera(CameraUpdate.zoomOut());
                }),
                const SizedBox(height: 6),
                _zoomButton(
                  Icons.my_location,
                  'نواكشوط',
                  () {
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_defaultCenter, 13));
                  },
                  color: _kGreen,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

          // ── Bottom info card ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2)),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: _kGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الموقع المحدد', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 2),
                            _isLoadingAddress
                                ? _buildAddressShimmer()
                                : Text(
                                    _selectedAddress,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'الإحداثيات: ${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isLoadingAddress ? null : _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('تأكيد الموقع', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saveCurrentLocation,
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: const Text('حفظ هذا الموقع', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kGreen,
                        side: const BorderSide(color: _kGreen),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressShimmer() {
    return Container(
      height: 16,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _zoomButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    Color color = Colors.white,
    Color iconColor = Colors.black87,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}
