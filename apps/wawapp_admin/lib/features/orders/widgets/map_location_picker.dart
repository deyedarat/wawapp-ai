import 'dart:convert';

import 'package:flutter/material.dart';
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

// ============================================================================
// Static Data
// ============================================================================

const _kGreen = Color(0xFF00C853);

const _districts = <_District>[
  _District('تفرغ زينة', 'Tevragh-Zeina', Color(0xFFFF6B6B), [
    LatLng(18.115, -15.990), LatLng(18.115, -15.955),
    LatLng(18.095, -15.945), LatLng(18.085, -15.950), LatLng(18.085, -15.990),
  ]),
  _District('الميناء', 'El-Mina', Color(0xFF45B7D1), [
    LatLng(18.085, -15.990), LatLng(18.085, -15.960),
    LatLng(18.065, -15.960), LatLng(18.055, -15.975), LatLng(18.055, -15.990),
  ]),
  _District('تيارت', 'Teyarett', Color(0xFF96CEB4), [
    LatLng(18.095, -15.960), LatLng(18.095, -15.945),
    LatLng(18.075, -15.940), LatLng(18.065, -15.945), LatLng(18.065, -15.960),
  ]),
  _District('توجنين', 'Toujounine', Color(0xFFFFEAA7), [
    LatLng(18.085, -15.945), LatLng(18.085, -15.920),
    LatLng(18.065, -15.920), LatLng(18.055, -15.930),
    LatLng(18.055, -15.945), LatLng(18.065, -15.945),
  ]),
  _District('دار النعيم', 'Dar-Naim', Color(0xFFDDA0DD), [
    LatLng(18.095, -15.920), LatLng(18.095, -15.890),
    LatLng(18.065, -15.890), LatLng(18.065, -15.920),
  ]),
  _District('لكصر', 'Kébé', Color(0xFF4ECDC4), [
    LatLng(18.115, -15.955), LatLng(18.115, -15.920),
    LatLng(18.095, -15.920), LatLng(18.085, -15.930),
    LatLng(18.085, -15.945), LatLng(18.095, -15.945),
  ]),
  _District('السبخة', 'Sebkha', Color(0xFF98D8C8), [
    LatLng(18.065, -15.990), LatLng(18.065, -15.960),
    LatLng(18.035, -15.960), LatLng(18.025, -15.975), LatLng(18.025, -15.990),
  ]),
  _District('عرفات', 'Arafat', Color(0xFF87CEEB), [
    LatLng(18.035, -15.975), LatLng(18.035, -15.940),
    LatLng(18.005, -15.940), LatLng(18.000, -15.960), LatLng(18.000, -15.975),
  ]),
  _District('الرياض', 'Riadh', Color(0xFFF0A500), [
    LatLng(18.065, -15.960), LatLng(18.065, -15.940),
    LatLng(18.045, -15.940), LatLng(18.035, -15.950), LatLng(18.035, -15.960),
  ]),
];

const _pois = <_Poi>[
  _Poi('مطعم النخيل', 'Restaurant Najmat', LatLng(18.0868, -15.9703), '🍽️', Color(0xFFE74C3C)),
  _Poi('مطعم الدبلوماسي', 'Le Diplomate', LatLng(18.0845, -15.9721), '🍽️', Color(0xFFE74C3C)),
  _Poi('مطعم الأمير', 'Restaurant Al-Amir', LatLng(18.0912, -15.9680), '🍽️', Color(0xFFE74C3C)),
  _Poi('مطعم السنجق', 'Restaurant Sanjak', LatLng(18.0830, -15.9755), '🍽️', Color(0xFFE74C3C)),
  _Poi('مطعم الجزيرة', 'Restaurant Al-Jazira', LatLng(18.110, -15.958), '🍽️', Color(0xFFE74C3C)),
  _Poi('فندق نواكشوط', 'Hôtel Novotel', LatLng(18.0935, -15.9655), '🏨', Color(0xFF9B59B6)),
  _Poi('فندق الشيراتون', 'Hôtel Sheraton', LatLng(18.100, -15.960), '🏨', Color(0xFF9B59B6)),
  _Poi('السوق الخماسي', 'Marché Cinquième', LatLng(18.0842, -15.9810), '🛒', Color(0xFF27AE60)),
  _Poi('السوق المركزي', 'Marché Central', LatLng(18.0795, -15.9750), '🛒', Color(0xFF27AE60)),
  _Poi('سوبرماركت نجمة', 'Supermarchée Najma', LatLng(18.0925, -15.9730), '🏪', Color(0xFF27AE60)),
  _Poi('محطة وقود توتال', 'Station Total', LatLng(18.0900, -15.9690), '⛽', Color(0xFFF39C12)),
  _Poi('محطة وقود الأمل', 'Station Shell', LatLng(18.0820, -15.9720), '⛽', Color(0xFFF39C12)),
  _Poi('المستشفى الوطني', 'Hôpital National', LatLng(18.0880, -15.9745), '🏥', Color(0xFFE91E63)),
  _Poi('مستشفى ابن سينا', 'Hôpital Ibn Sina', LatLng(18.080, -15.920), '🏥', Color(0xFFE91E63)),
  _Poi('جامعة نواكشوط', 'Université de Nouakchott', LatLng(18.0855, -15.9695), '🎓', Color(0xFF3498DB)),
  _Poi('بنك موريتانيا', 'Banque de Mauritanie', LatLng(18.0875, -15.9715), '🏦', Color(0xFF1ABC9C)),
  _Poi('بنك BIM', 'BIM Bank', LatLng(18.0912, -15.9668), '🏦', Color(0xFF1ABC9C)),
  _Poi('مسجد الرحمة', 'Mosquée Rahma', LatLng(18.0865, -15.9770), '🕌', Color(0xFF2ECC71)),
  _Poi('مسجد النور', 'Mosquée Nour', LatLng(18.0920, -15.9700), '🕌', Color(0xFF2ECC71)),
  _Poi('القصر الرئاسي', 'Palais Présidentiel', LatLng(18.0895, -15.9660), '🏛️', Color(0xFF8E44AD)),
  _Poi('سفارة فرنسا', 'Ambassade de France', LatLng(18.105, -15.975), '🏛️', Color(0xFF8E44AD)),
  _Poi('ملعب الأمير', 'Stade Olympique', LatLng(18.0840, -15.9600), '🏟️', Color(0xFFE67E22)),
  _Poi('شاطئ المدينة', 'Plage de Nouakchott', LatLng(18.090, -16.005), '🏖️', Color(0xFFE74C3C)),
  _Poi('ميناء نواكشوط', 'Port de Nouakchott', LatLng(18.130, -15.970), '⚓', Color(0xFFE74C3C)),
  _Poi('مطار نواكشوط', 'Aéroport International', LatLng(18.125, -15.960), '✈️', Color(0xFFE74C3C)),
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
  bool _showPois = true;
  bool _showDistricts = true;
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
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http.get(url, headers: {'User-Agent': 'WawApp-Admin/1.0'});
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
    setState(() {
      _selectedPosition = position;
      _selectedAddress = 'جار تحديد العنوان...';
      _isLoadingAddress = true;
    });
    _mapController.move(position, _mapController.camera.zoom);
    final address = await _getAddressFromLatLng(position.latitude, position.longitude);
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isLoadingAddress = false;
      });
    }
  }

  void _confirmSelection() {
    if (_selectedPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تحديد موقع على الخريطة'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.of(context).pop(LocationData(
      address: _selectedAddress,
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
    ));
  }

  void _searchPlace(String query) {
    if (query.isEmpty) return;
    final q = query.toLowerCase();
    // Search districts
    for (final d in _districts) {
      if (d.nameAr.contains(query) || d.nameFr.toLowerCase().contains(q)) {
        _mapController.move(d.center, 14);
        return;
      }
    }
    // Search POIs
    for (final p in _pois) {
      if (p.nameAr.contains(query) || p.nameFr.toLowerCase().contains(q)) {
        _mapController.move(p.position, 16);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لم يتم العثور على "$query"'), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  polygons: _districts.map((d) => Polygon(
                    points: d.coords,
                    color: d.color.withOpacity(0.25),
                    borderColor: d.color,
                    borderStrokeWidth: 2,
                    isFilled: true,
                  )).toList(),
                ),
              // District labels
              if (_showDistricts)
                MarkerLayer(
                  markers: _districts.map((d) => Marker(
                    point: d.center,
                    width: 120,
                    height: 36,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: d.color.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: d.color, width: 1),
                      ),
                      child: Text(
                        '${d.nameAr}\n${d.nameFr}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1a1a1a),
                          height: 1.2,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              // POI markers
              if (_showPois)
                MarkerLayer(
                  markers: _pois.map((p) => Marker(
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
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        alignment: Alignment.center,
                        child: Text(p.icon, style: const TextStyle(fontSize: 16)),
                      ),
                    ),
                  )).toList(),
                ),
              // Selected position marker
              if (_selectedPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPosition!,
                      width: 60,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kGreen,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.5), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4))],
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                          ),
                          CustomPaint(
                            size: const Size(14, 10),
                            painter: _MarkerTrianglePainter(_kGreen),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              RichAttributionWidget(
                animationConfig: const ScaleRAWA(),
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),

          // ── Search bar ──
          Positioned(
            top: 12,
            left: 60,
            right: 60,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '🔍 ابحث عن حي أو مكان...',
                  hintStyle: const TextStyle(fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: _kGreen),
                    onPressed: () => _searchPlace(_searchController.text),
                  ),
                ),
                textDirection: TextDirection.rtl,
                style: const TextStyle(fontSize: 13),
                onSubmitted: _searchPlace,
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xDD006400),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '🏙️ خريطة نواكشوط التفاعلية',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.remove, 'تصغير', () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.my_location, 'الموقع المحدد', () {
                  if (_selectedPosition != null) _mapController.move(_selectedPosition!, 16);
                }, color: _kGreen, iconColor: Colors.white),
              ],
            ),
          ),

          // ── Legend ──
          Positioned(
            left: 8,
            bottom: 180,
            child: _buildLegend(),
          ),

          // ── Bottom info card ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: _kGreen, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الموقع المحدد', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            const SizedBox(height: 4),
                            Text(
                              _selectedAddress,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_isLoadingAddress)
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  if (_selectedPosition != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'الإحداثيات: ${_selectedPosition!.latitude.toStringAsFixed(5)}, ${_selectedPosition!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoadingAddress ? null : _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('تأكيد الموقع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onPressed, {Color color = Colors.white, Color iconColor = Colors.black87}) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: IconButton(icon: Icon(icon, color: iconColor), onPressed: onPressed, tooltip: tooltip),
    );
  }

  void _showPoiInfo(_Poi poi) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${poi.icon} ${poi.nameAr} — ${poi.nameFr}', textDirection: TextDirection.rtl),
        backgroundColor: poi.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6)],
      ),
      constraints: const BoxConstraints(maxWidth: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🗺️ دليل الخريطة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const Divider(height: 8),
          const Text('المقاطعات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 2),
          ..._districts.map((d) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: d.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Text(d.nameAr, style: const TextStyle(fontSize: 9)),
              ],
            ),
          )),
          const SizedBox(height: 4),
          const Text('نقاط الاهتمام:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          const SizedBox(height: 2),
          const Text('🍽️ مطاعم  🏨 فنادق', style: TextStyle(fontSize: 9)),
          const Text('🛒 أسواق  ⛽ وقود', style: TextStyle(fontSize: 9)),
          const Text('🏥 مستشفيات  🎓 تعليم', style: TextStyle(fontSize: 9)),
          const Text('🏦 بنوك  🕌 مساجد', style: TextStyle(fontSize: 9)),
        ],
      ),
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
