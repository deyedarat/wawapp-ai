import 'package:google_maps_flutter/google_maps_flutter.dart';

class DistrictArea {
  final String id;
  final String nameAr;
  final String nameFr;
  final List<LatLng> polygonPoints;
  final LatLng labelPosition;

  const DistrictArea({
    required this.id,
    required this.nameAr,
    required this.nameFr,
    required this.polygonPoints,
    required this.labelPosition,
  });

  String getName(String languageCode) {
    return languageCode == 'ar' ? nameAr : nameFr;
  }
}
