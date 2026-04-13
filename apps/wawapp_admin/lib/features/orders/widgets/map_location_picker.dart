import 'dart:async';
import 'dart:convert';
import 'dart:math' show Point;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' hide Path;

// ============================================================================
// Data Models
// ============================================================================

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

class _District {
  final String nameAr;
  final String nameFr;
  final Color color;
  final List<LatLng> coords;

  const _District(this.nameAr, this.nameFr, this.color, this.coords);

  LatLng get center {
    double lat = 0, lng = 0;
    for (final c in coords) {
      lat += c.latitude;
      lng += c.longitude;
    }
    return LatLng(lat / coords.length, lng / coords.length);
  }
}

class _Poi {
  final String nameAr;
  final String nameFr;
  final LatLng position;
  final String icon;
  final Color color;

  const _Poi(this.nameAr, this.nameFr, this.position, this.icon, this.color);
}

class _SearchResult {
  final String displayName;
  final LatLng position;
  final String type;

  const _SearchResult(this.displayName, this.position, this.type);
}

class _HotSpot {
  final String nameAr;
  final String nameFr;
  final LatLng position;
  final String category;
  final String icon;

  const _HotSpot(
      this.nameAr, this.nameFr, this.position, this.category, this.icon);
}

// ============================================================================
// Static Data
// ============================================================================

const _kGreen = Color(0xFF00C853);

// مواقف المشاكل والنقاط الساخنة
const _hotSpots = <_HotSpot>[
  // مواقف المشاكل (أماكن انتظار السائقين)
  _HotSpot('موقف المشاكل - السوق الخماسي', 'Station Marché 5',
      LatLng(18.0845, -15.9815), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - السوق المركزي', 'Station Marché Central',
      LatLng(18.0800, -15.9755), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - المطار', 'Station Aéroport', LatLng(18.125, -15.960),
      'موقف', '🚖'),
  _HotSpot('موقف المشاكل - الميناء', 'Station Port', LatLng(18.130, -15.970),
      'موقف', '🚖'),
  _HotSpot('موقف المشاكل - الجامعة', 'Station Université',
      LatLng(18.0860, -15.9700), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - المستشفى الوطني', 'Station Hôpital',
      LatLng(18.0885, -15.9750), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - محطة الحافلات', 'Station Gare Routière',
      LatLng(18.082, -15.978), 'موقف', '🚖'),
  _HotSpot('موقف المشاكل - السوق الكبير', 'Station Grand Marché',
      LatLng(18.085, -15.980), 'موقف', '🚖'),

  // النقاط الساخنة (مناطق ذروة الطلب)
  _HotSpot('نقطة ساخنة - تفرغ زينة', 'Hot Spot Tevragh-Zeina',
      LatLng(18.105, -15.972), 'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - الميناء', 'Hot Spot El-Mina', LatLng(18.075, -15.975),
      'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - السبخة', 'Hot Spot Sebkha', LatLng(18.045, -15.975),
      'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - عرفات', 'Hot Spot Arafat', LatLng(18.020, -15.957),
      'نقطة ساخنة', '🔥'),
  _HotSpot('نقطة ساخنة - الرياض', 'Hot Spot Riadh', LatLng(18.055, -15.950),
      'نقطة ساخنة', '🔥'),
];

const _districts = <_District>[
  _District('تفرغ زينة', 'Tevragh-Zeina', Color(0xFFFF6B6B), [
    LatLng(18.115, -15.990),
    LatLng(18.115, -15.955),
    LatLng(18.095, -15.945),
    LatLng(18.085, -15.950),
    LatLng(18.085, -15.990),
  ]),
  _District('الميناء', 'El-Mina', Color(0xFF45B7D1), [
    LatLng(18.085, -15.990),
    LatLng(18.085, -15.960),
    LatLng(18.065, -15.960),
    LatLng(18.055, -15.975),
    LatLng(18.055, -15.990),
  ]),
  _District('تيارت', 'Teyarett', Color(0xFF96CEB4), [
    LatLng(18.095, -15.960),
    LatLng(18.095, -15.945),
    LatLng(18.075, -15.940),
    LatLng(18.065, -15.945),
    LatLng(18.065, -15.960),
  ]),
  _District('توجنين', 'Toujounine', Color(0xFFFFEAA7), [
    LatLng(18.085, -15.945),
    LatLng(18.085, -15.920),
    LatLng(18.065, -15.920),
    LatLng(18.055, -15.930),
    LatLng(18.055, -15.945),
    LatLng(18.065, -15.945),
  ]),
  _District('دار النعيم', 'Dar-Naim', Color(0xFFDDA0DD), [
    LatLng(18.095, -15.920),
    LatLng(18.095, -15.890),
    LatLng(18.065, -15.890),
    LatLng(18.065, -15.920),
  ]),
  _District('لكصر', 'Kébé', Color(0xFF4ECDC4), [
    LatLng(18.115, -15.955),
    LatLng(18.115, -15.920),
    LatLng(18.095, -15.920),
    LatLng(18.085, -15.930),
    LatLng(18.085, -15.945),
    LatLng(18.095, -15.945),
  ]),
  _District('السبخة', 'Sebkha', Color(0xFF98D8C8), [
    LatLng(18.065, -15.990),
    LatLng(18.065, -15.960),
    LatLng(18.035, -15.960),
    LatLng(18.025, -15.975),
    LatLng(18.025, -15.990),
  ]),
  _District('عرفات', 'Arafat', Color(0xFF87CEEB), [
    LatLng(18.035, -15.975),
    LatLng(18.035, -15.940),
    LatLng(18.005, -15.940),
    LatLng(18.000, -15.960),
    LatLng(18.000, -15.975),
  ]),
  _District('الرياض', 'Riadh', Color(0xFFF0A500), [
    LatLng(18.065, -15.960),
    LatLng(18.065, -15.940),
    LatLng(18.045, -15.940),
    LatLng(18.035, -15.950),
    LatLng(18.035, -15.960),
  ]),
];

const _pois = <_Poi>[
  _Poi('مطعم النخيل', 'Restaurant Najmat', LatLng(18.0868, -15.9703), '🍽️',
      Color(0xFFE74C3C)),
  _Poi('مطعم الدبلوماسي', 'Le Diplomate', LatLng(18.0845, -15.9721), '🍽️',
      Color(0xFFE74C3C)),
  _Poi('مطعم الأمير', 'Restaurant Al-Amir', LatLng(18.0912, -15.9680), '🍽️',
      Color(0xFFE74C3C)),
  _Poi('مطعم السنجق', 'Restaurant Sanjak', LatLng(18.0830, -15.9755), '🍽️',
      Color(0xFFE74C3C)),
  _Poi('مطعم الجزيرة', 'Restaurant Al-Jazira', LatLng(18.110, -15.958), '🍽️',
      Color(0xFFE74C3C)),
  _Poi('فندق نواكشوط', 'Hôtel Novotel', LatLng(18.0935, -15.9655), '🏨',
      Color(0xFF9B59B6)),
  _Poi('فندق الشيراتون', 'Hôtel Sheraton', LatLng(18.100, -15.960), '🏨',
      Color(0xFF9B59B6)),
  _Poi('السوق الخماسي', 'Marché Cinquième', LatLng(18.0842, -15.9810), '🛒',
      Color(0xFF27AE60)),
  _Poi('السوق المركزي', 'Marché Central', LatLng(18.0795, -15.9750), '🛒',
      Color(0xFF27AE60)),
  _Poi('سوبرماركت نجمة', 'Supermarchée Najma', LatLng(18.0925, -15.9730), '🏪',
      Color(0xFF27AE60)),
  _Poi('محطة وقود توتال', 'Station Total', LatLng(18.0900, -15.9690), '⛽',
      Color(0xFFF39C12)),
  _Poi('محطة وقود الأمل', 'Station Shell', LatLng(18.0820, -15.9720), '⛽',
      Color(0xFFF39C12)),
  _Poi('المستشفى الوطني', 'Hôpital National', LatLng(18.0880, -15.9745), '🏥',
      Color(0xFFE91E63)),
  _Poi('مستشفى ابن سينا', 'Hôpital Ibn Sina', LatLng(18.080, -15.920), '🏥',
      Color(0xFFE91E63)),
  _Poi('جامعة نواكشوط', 'Université de Nouakchott', LatLng(18.0855, -15.9695),
      '🎓', Color(0xFF3498DB)),
  _Poi('بنك موريتانيا', 'Banque de Mauritanie', LatLng(18.0875, -15.9715), '🏦',
      Color(0xFF1ABC9C)),
  _Poi('بنك BIM', 'BIM Bank', LatLng(18.0912, -15.9668), '🏦',
      Color(0xFF1ABC9C)),
  _Poi('مسجد الرحمة', 'Mosquée Rahma', LatLng(18.0865, -15.9770), '🕌',
      Color(0xFF2ECC71)),
  _Poi('مسجد النور', 'Mosquée Nour', LatLng(18.0920, -15.9700), '🕌',
      Color(0xFF2ECC71)),
  _Poi('القصر الرئاسي', 'Palais Présidentiel', LatLng(18.0895, -15.9660), '🏛️',
      Color(0xFF8E44AD)),
  _Poi('سفارة فرنسا', 'Ambassade de France', LatLng(18.105, -15.975), '🏛️',
      Color(0xFF8E44AD)),
  _Poi('ملعب الأمير', 'Stade Olympique', LatLng(18.0840, -15.9600), '🏟️',
      Color(0xFFE67E22)),
  _Poi('شاطئ المدينة', 'Plage de Nouakchott', LatLng(18.090, -16.005), '🏖️',
      Color(0xFFE74C3C)),
  _Poi('ميناء نواكشوط', 'Port de Nouakchott', LatLng(18.130, -15.970), '⚓',
      Color(0xFFE74C3C)),
  _Poi('مطار نواكشوط', 'Aéroport International', LatLng(18.125, -15.960), '✈️',
      Color(0xFFE74C3C)),
];

// ============================================================================
// Widget
// ============================================================================

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
  bool _isGettingLocation = false;
  bool _isDragging = false;
  bool _showPois = true;
  bool _showDistricts = true;
  bool _isSearching = false;
  bool _legendExpanded = false;
  List<_SearchResult> _searchResults = [];
  List<Map<String, dynamic>> _savedLocations = [];
  final List<LocationData> _recentLocations = [];
  Timer? _searchDebounce;
  final _searchController = TextEditingController();

  static const LatLng _defaultCenter = LatLng(18.0832, -15.9741);

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
    _loadSavedLocations();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedLocations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('admin_saved_locations')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['locations'] != null) {
        setState(() {
          _savedLocations =
              List<Map<String, dynamic>>.from(doc.data()!['locations']);
        });
      }
    } catch (e) {
      debugPrint('Error loading saved locations: $e');
    }
  }

  Future<void> _saveCurrentLocation() async {
    if (_selectedPosition == null) return;
    final nameController = TextEditingController(
        text: '\u0645\u0648\u0642\u0639 ${_savedLocations.length + 1}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
            '\u062d\u0641\u0638 \u0627\u0644\u0645\u0648\u0642\u0639'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
              labelText:
                  '\u0627\u0633\u0645 \u0627\u0644\u0645\u0648\u0642\u0639',
              hintText:
                  '\u0645\u062b\u0627\u0644: \u0645\u0643\u062a\u0628 \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a'),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('\u0625\u0644\u063a\u0627\u0621')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
            child: const Text('\u062d\u0641\u0638'),
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
      await FirebaseFirestore.instance
          .collection('admin_saved_locations')
          .doc(user.uid)
          .set({'locations': updated}, SetOptions(merge: true));
      setState(() => _savedLocations = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  '\u062a\u0645 \u062d\u0641\u0638 \u0627\u0644\u0645\u0648\u0642\u0639 \u0628\u0646\u062c\u0627\u062d'),
              backgroundColor: _kGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '\u062e\u0637\u0623 \u0641\u064a \u062d\u0641\u0638 \u0627\u0644\u0645\u0648\u0642\u0639: $e'),
              backgroundColor: Colors.red),
        );
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
                '\u0627\u0644\u0645\u0648\u0627\u0642\u0639 \u0627\u0644\u0645\u062d\u0641\u0648\u0638\u0629',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const Divider(),
            if (_savedLocations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                    '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0648\u0627\u0642\u0639 \u0645\u062d\u0641\u0648\u0638\u0629',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center),
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
                          child: Icon(Icons.bookmark,
                              color: Colors.white, size: 20)),
                      title: Text(loc['name'] as String),
                      subtitle: Text(loc['address'] as String,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteSavedLocation(index),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        final pos = LatLng(loc['latitude'] as double,
                            loc['longitude'] as double);
                        _mapController.move(pos, 16);
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

  Future<void> _deleteSavedLocation(int index) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final updated = List<Map<String, dynamic>>.from(_savedLocations)
        ..removeAt(index);
      await FirebaseFirestore.instance
          .collection('admin_saved_locations')
          .doc(user.uid)
          .set({'locations': updated}, SetOptions(merge: true));
      setState(() => _savedLocations = updated);
      if (mounted) {
        Navigator.pop(context);
        _showSavedLocations();
      }
    } catch (e) {
      debugPrint('Error deleting location: $e');
    }
  }

  Future<bool> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> _goToMyLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      if (!await _checkLocationPermission()) {
        throw 'Location permission denied';
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في تحديد الموقع: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response =
          await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'عنوان غير معروف';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return 'الموقع: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng position) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedPosition = position;
      _selectedAddress =
          '\u062c\u0627\u0631 \u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0639\u0646\u0648\u0627\u0646...';
      _isLoadingAddress = true;
    });
    _mapController.move(position, _mapController.camera.zoom);
    final address =
        await _getAddressFromLatLng(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
        _recentLocations.insert(
            0,
            LocationData(
                address: address,
                latitude: position.latitude,
                longitude: position.longitude));
        if (_recentLocations.length > 5) _recentLocations.removeLast();
      });
    }
  }

  void _confirmSelection() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('الرجاء تحديد موقع على الخريطة'),
            backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.of(context).pop(LocationData(
      address: _selectedAddress,
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
    ));
  }

  Future<List<_SearchResult>> _searchNominatim(String query) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'format=json&limit=5&countrycodes=mr&accept-language=ar&'
        'bounded=1&viewbox=-16.05,18.15,-15.85,18.00',
      );
      final response =
          await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .map((item) => _SearchResult(
                  item['display_name'] as String,
                  LatLng(double.parse(item['lat'] as String),
                      double.parse(item['lon'] as String)),
                  'nominatim',
                ))
            .toList();
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    }
    return [];
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = <_SearchResult>[];
    final q = query.toLowerCase();
    final qAr = query; // للبحث بالعربية

    // 1. البحث في مواقف المشاكل والنقاط الساخنة (أولوية عالية)
    for (final h in _hotSpots) {
      if (h.nameAr.contains(qAr) ||
          h.nameFr.toLowerCase().contains(q) ||
          h.category.contains(qAr)) {
        results.add(_SearchResult(
            '${h.icon} ${h.nameAr} (${h.category})', h.position, 'hotspot'));
      }
    }

    // 2. البحث في المقاطعات
    for (final d in _districts) {
      if (d.nameAr.contains(qAr) || d.nameFr.toLowerCase().contains(q)) {
        results.add(_SearchResult('مقاطعة ${d.nameAr}', d.center, 'district'));
      }
    }

    // 3. البحث في نقاط الاهتمام
    for (final p in _pois) {
      if (p.nameAr.contains(qAr) || p.nameFr.toLowerCase().contains(q)) {
        results.add(_SearchResult('${p.icon} ${p.nameAr}', p.position, 'poi'));
      }
    }

    // 4. البحث في المواقع المحفوظة
    for (final saved in _savedLocations) {
      final name = saved['name'] as String;
      final address = saved['address'] as String;
      if (name.contains(qAr) || address.contains(qAr)) {
        results.add(_SearchResult(
            '📌 $name',
            LatLng(saved['latitude'] as double, saved['longitude'] as double),
            'saved'));
      }
    }

    // 5. إذا لم نجد نتائج كافية، استخدم Nominatim
    if (results.length < 3) {
      results.addAll(await _searchNominatim(query));
    }

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showDistricts ? Icons.map : Icons.map_outlined),
            tooltip: _showDistricts ? 'إخفاء المقاطعات' : 'إظهار المقاطعات',
            onPressed: () => setState(() => _showDistricts = !_showDistricts),
          ),
          IconButton(
            icon: Icon(_showPois ? Icons.place : Icons.place_outlined),
            tooltip: _showPois ? 'إخفاء نقاط الاهتمام' : 'إظهار نقاط الاهتمام',
            onPressed: () => setState(() => _showPois = !_showPois),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedPosition ?? _defaultCenter,
              initialZoom: 13.0,
              minZoom: 3.0,
              maxZoom: 19.0,
              onTap: _onMapTap,
              onLongPress: (tapPosition, point) {
                _onMapTap(tapPosition, point);
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
                enableMultiFingerGestureRace: true,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.wawapp.admin',
                maxZoom: 19,
                tileProvider: NetworkTileProvider(),
              ),
              // District polygons
              if (_showDistricts)
                PolygonLayer(
                  polygons: _districts
                      .map((d) => Polygon(
                            points: d.coords,
                            color: d.color.withOpacity(0.08),
                            borderColor: d.color.withOpacity(0.5),
                            borderStrokeWidth: 1.5,
                            isFilled: true,
                          ))
                      .toList(),
                ),
              // District labels
              if (_showDistricts)
                MarkerLayer(
                  markers: _districts
                      .map((d) => Marker(
                            point: d.center,
                            width: 120,
                            height: 36,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: d.color.withOpacity(0.6), width: 1),
                              ),
                              child: Text(
                                '${d.nameAr}\n${d.nameFr}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: d.color.withOpacity(0.9),
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              // POI markers
              if (_showPois)
                MarkerLayer(
                  markers: _pois
                      .map((p) => Marker(
                            point: p.position,
                            width: 32,
                            height: 32,
                            child: GestureDetector(
                              onTap: () => _showPoiInfo(p),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: p.color, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(p.icon,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              // Selected position marker (draggable)
              if (_selectedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPosition!,
                      width: 60,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onPanStart: (_) => setState(() {
                          _isDragging = true;
                          _selectedAddress =
                              '\u062c\u0627\u0631 \u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0639\u0646\u0648\u0627\u0646...';
                        }),
                        onPanUpdate: (details) {
                          final camera = _mapController.camera;
                          final pt =
                              camera.latLngToScreenPoint(_selectedPosition!);
                          final newPt = Point<double>(
                              pt.x + details.delta.dx, pt.y + details.delta.dy);
                          final newLatLng = camera.pointToLatLng(newPt);
                          setState(() {
                            _selectedPosition = newLatLng;
                            _selectedAddress =
                                '\u0627\u0644\u0625\u062d\u062f\u0627\u062b\u064a\u0627\u062a: ${newLatLng.latitude.toStringAsFixed(5)}, ${newLatLng.longitude.toStringAsFixed(5)}';
                          });
                        },
                        onPanEnd: (_) async {
                          setState(() {
                            _isDragging = false;
                            _isLoadingAddress = true;
                            _selectedAddress =
                                '\u062c\u0627\u0631 \u062a\u062d\u062f\u064a\u062f \u0627\u0644\u0639\u0646\u0648\u0627\u0646...';
                          });
                          final address = await _getAddressFromLatLng(
                            _selectedPosition!.latitude,
                            _selectedPosition!.longitude,
                          );
                          if (mounted) {
                            setState(() {
                              _selectedAddress = address;
                              _isLoadingAddress = false;
                            });
                          }
                        },
                        child: AnimatedScale(
                          scale: _isDragging ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kGreen,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _kGreen
                                          .withOpacity(_isDragging ? 0.8 : 0.5),
                                      blurRadius: _isDragging ? 20 : 12,
                                      spreadRadius: _isDragging ? 4 : 2,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.location_on,
                                    color: Colors.white, size: 24),
                              ),
                              CustomPaint(
                                size: const Size(14, 10),
                                painter: _MarkerTrianglePainter(_kGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                animationConfig: const ScaleRAWA(),
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors',
                      onTap: () {}),
                ],
              ),
            ],
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
                      BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث عن موقع...',
                      hintStyle: const TextStyle(fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: InputBorder.none,
                      prefixIcon:
                          const Icon(Icons.search, size: 20, color: _kGreen),
                      suffixIcon: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : null,
                    ),
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 12),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce =
                          Timer(const Duration(milliseconds: 500), () {
                        _performSearch(value);
                      });
                    },
                    onSubmitted: _performSearch,
                  ),
                ),
                // Quick search shortcuts
                if (_searchResults.isEmpty && _searchController.text.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6, left: 8, right: 8),
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _quickSearchChip('🚖 مواقف', 'موقف المشاكل'),
                        _quickSearchChip('🔥 نقاط ساخنة', 'نقطة ساخنة'),
                        _quickSearchChip('🍽️ مطاعم', 'مطعم'),
                        _quickSearchChip('🏨 فنادق', 'فندق'),
                        _quickSearchChip('⛽ وقود', 'محطة وقود'),
                        _quickSearchChip('🏥 مستشفيات', 'مستشفى'),
                      ],
                    ),
                  ),
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.2), blurRadius: 8)
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final r = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            r.type == 'hotspot'
                                ? Icons.local_taxi
                                : r.type == 'district'
                                    ? Icons.map
                                    : r.type == 'poi'
                                        ? Icons.place
                                        : r.type == 'saved'
                                            ? Icons.bookmark
                                            : Icons.location_on,
                            color: r.type == 'hotspot'
                                ? Colors.orange
                                : r.type == 'saved'
                                    ? _kGreen
                                    : _kGreen,
                            size: 20,
                          ),
                          title: Text(r.displayName,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: r.type == 'hotspot'
                                      ? FontWeight.bold
                                      : FontWeight.normal),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          onTap: () async {
                            // تكبير أكبر للنقاط الساخنة
                            final zoom = r.type == 'hotspot'
                                ? 17.0
                                : r.type == 'district'
                                    ? 14.0
                                    : 16.0;

                            _mapController.move(r.position, zoom);
                            setState(() {
                              _selectedPosition = r.position;
                              _selectedAddress = 'جار تحديد العنوان...';
                              _isLoadingAddress = true;
                              _searchResults = [];
                            });
                            _searchController.clear();

                            final address = await _getAddressFromLatLng(
                                r.position.latitude, r.position.longitude);

                            if (mounted) {
                              setState(() {
                                _selectedAddress = address;
                                _isLoadingAddress = false;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // ── Title bar ──
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xDD006400),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🏙️ خريطة نواكشوط التفاعلية',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

          // ── Zoom controls ──
          Positioned(
            right: 12,
            top: 70,
            child: Column(
              children: [
                _zoomButton(Icons.add, 'تكبير', () {
                  _mapController.move(_mapController.camera.center,
                      _mapController.camera.zoom + 1);
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.remove, 'تصغير', () {
                  _mapController.move(_mapController.camera.center,
                      _mapController.camera.zoom - 1);
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.my_location, 'الموقع المحدد', () {
                  if (_selectedPosition != null)
                    _mapController.move(_selectedPosition!, 16);
                }, color: _kGreen, iconColor: Colors.white),
                const SizedBox(height: 6),
                _zoomButton(
                  _isGettingLocation ? Icons.hourglass_empty : Icons.gps_fixed,
                  'موقعي الحالي',
                  _goToMyLocation,
                  color: _kGreen,
                  iconColor: Colors.white,
                ),
              ],
            ),
          ),

          // ── Coordinate tooltip during drag ──
          if (_isDragging && _selectedPosition != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),

          // ── Recent locations chips ──
          if (_recentLocations.isNotEmpty)
            Positioned(
              bottom: 200,
              left: 8,
              right: 8,
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recentLocations.length,
                  itemBuilder: (context, index) {
                    final loc = _recentLocations[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: const Icon(Icons.history, size: 16),
                        label: Text(
                          loc.address.length > 30
                              ? '${loc.address.substring(0, 27)}...'
                              : loc.address,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          final pos = LatLng(loc.latitude, loc.longitude);
                          _mapController.move(pos, 16);
                          setState(() {
                            _selectedPosition = pos;
                            _selectedAddress = loc.address;
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ),

          // ── Legend ──
          Positioned(
            left: 8,
            bottom: 245,
            child: _buildLegend(),
          ),

          // ── Bottom info card (compact version) ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2))
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
                            Text('الموقع المحدد',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600])),
                            const SizedBox(height: 2),
                            _isLoadingAddress
                                ? _buildAddressShimmer()
                                : Text(
                                    _selectedAddress,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ],
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('تأكيد الموقع',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _saveCurrentLocation,
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: const Text('حفظ هذا الموقع',
                          style: TextStyle(fontSize: 13)),
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

  // ── Helpers ──

  Widget _quickSearchChip(String label, String searchTerm) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: () {
          _searchController.text = searchTerm;
          _performSearch(searchTerm);
        },
        backgroundColor: Colors.white,
        side: BorderSide(color: _kGreen.withOpacity(0.3)),
      ),
    );
  }

  Widget _buildAddressShimmer() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, _) => Opacity(
        opacity: value,
        child: Container(
          height: 16,
          width: double.infinity,
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
        ),
      ),
      onEnd: () {
        if (_isLoadingAddress) setState(() {});
      },
    );
  }

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onPressed,
      {Color color = Colors.white, Color iconColor = Colors.black87}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: IconButton(
          icon: Icon(icon, color: iconColor),
          onPressed: onPressed,
          tooltip: tooltip),
    );
  }

  void _showPoiInfo(_Poi poi) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${poi.icon} ${poi.nameAr} — ${poi.nameFr}',
            textDirection: TextDirection.rtl),
        backgroundColor: poi.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapsed state - just icon button
        if (!_legendExpanded)
          Material(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            elevation: 3,
            child: IconButton(
              icon: const Icon(Icons.map, size: 22, color: _kGreen),
              tooltip: 'إظهار دليل الخريطة',
              onPressed: () => setState(() => _legendExpanded = true),
            ),
          ),

        // Expanded state - full legend
        if (_legendExpanded)
          Material(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(10),
            elevation: 3,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🗺️ دليل الخريطة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () =>
                            setState(() => _legendExpanded = false),
                      ),
                    ],
                  ),
                  const Divider(height: 8),

                  // Districts
                  const Text('المقاطعات:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  const SizedBox(height: 2),
                  ..._districts.map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: d.color,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 4),
                            Text(d.nameAr, style: const TextStyle(fontSize: 9)),
                          ],
                        ),
                      )),

                  const SizedBox(height: 4),

                  // POIs
                  const Text('نقاط الاهتمام:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  const SizedBox(height: 2),
                  const Text('🍽️ مطاعم  🏨 فنادق',
                      style: TextStyle(fontSize: 9)),
                  const Text('🛒 أسواق  ⛽ وقود', style: TextStyle(fontSize: 9)),
                  const Text('🏥 مستشفيات  🎓 تعليم',
                      style: TextStyle(fontSize: 9)),
                  const Text('🏦 بنوك  🕌 مساجد',
                      style: TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MarkerTrianglePainter extends CustomPainter {
  final Color color;
  const _MarkerTrianglePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MarkerTrianglePainter old) => old.color != color;
}
