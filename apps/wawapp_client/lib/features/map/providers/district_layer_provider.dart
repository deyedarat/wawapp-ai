import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/district_area.dart';
import '../data/nouakchott_districts.dart';

// Cache markers by zoom level and language
final Map<String, Set<Marker>> _markerCache = {};
// Memory Optimization Phase 2: Limit cache to 5 zoom levels
const int _maxCacheSize = 5;

final currentZoomProvider = StateProvider<double>((ref) => 14.0);

final districtAreasProvider = Provider<List<DistrictArea>>((ref) {
  return nouakchottDistricts;
});

final districtPolygonsProvider = Provider<Set<Polygon>>((ref) {
  final zoom = ref.watch(currentZoomProvider);
  if (zoom < 11) return {};

  final districts = ref.watch(districtAreasProvider);
  return districts.map((district) {
    return Polygon(
      polygonId: PolygonId(district.id),
      points: district.polygonPoints,
      strokeColor: Colors.white.withValues(alpha: 0.5),
      strokeWidth: 1,
      fillColor: Colors.transparent,
    );
  }).toSet();
});

final districtMarkersProvider = FutureProvider.family
    .autoDispose<Set<Marker>, String>((ref, languageCode) async {
  final zoom = ref.watch(currentZoomProvider);
  // Memory Optimization Phase 2: Only render markers at zoom >= 10
  if (zoom < 10 || zoom > 16) return {};

  // Cache key combines zoom level and language
  final cacheKey = '${zoom}_$languageCode';

  // Return cached markers if available
  if (_markerCache.containsKey(cacheKey)) {
    return _markerCache[cacheKey]!;
  }

  // Generate new markers if not cached
  final districts = ref.watch(districtAreasProvider);
  final markers = <Marker>{};

  for (final district in districts) {
    final icon = await _createTextMarker(district.getName(languageCode));
    markers.add(
      Marker(
        markerId: MarkerId('label_${district.id}'),
        position: district.labelPosition,
        icon: icon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 1,
      ),
    );
  }

  // Store in cache
  _markerCache[cacheKey] = markers;

  // Memory Optimization Phase 2: Evict old cache entries if needed
  _evictOldCacheIfNeeded();

  // Clear cache when districts update
  ref.listen(districtAreasProvider, (previous, next) {
    _markerCache.clear();
  });

  return markers;
});

// Memory Optimization Phase 2: LRU cache eviction
void _evictOldCacheIfNeeded() {
  if (_markerCache.length > _maxCacheSize) {
    // Remove oldest entry (first key)
    _markerCache.remove(_markerCache.keys.first);
  }
}

Future<BitmapDescriptor> _createTextMarker(String text) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const textStyle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    shadows: [
      Shadow(color: Colors.black87, offset: Offset(1, 1), blurRadius: 3),
    ],
  );

  final textSpan = TextSpan(text: text, style: textStyle);
  final textPainter = TextPainter(
    text: textSpan,
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  );

  textPainter.layout();
  textPainter.paint(canvas, Offset.zero);

  final picture = recorder.endRecording();
  final img = await picture.toImage(
    textPainter.width.ceil(),
    textPainter.height.ceil(),
  );
  final data = await img.toByteData(format: ui.ImageByteFormat.png);

  return BitmapDescriptor.bytes(data!.buffer.asUint8List());
}
