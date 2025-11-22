import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/district_area.dart';
import '../data/nouakchott_districts.dart';

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

final districtMarkersProvider =
    FutureProvider.family<Set<Marker>, String>((ref, languageCode) async {
  final zoom = ref.watch(currentZoomProvider);
  if (zoom < 11 || zoom > 16) return {};

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

  return markers;
});

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
