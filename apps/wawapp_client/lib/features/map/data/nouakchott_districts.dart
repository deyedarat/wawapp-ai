import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/district_area.dart';

/// Static data for Nouakchott districts with approximate boundaries
/// TODO: Replace with accurate GeoJSON data when available
const nouakchottDistricts = <DistrictArea>[
  DistrictArea(
    id: 'tevragh_zeina',
    nameAr: 'تفرغ زينة',
    nameFr: 'Tevragh Zeina',
    polygonPoints: [
      LatLng(18.0950, -15.9750),
      LatLng(18.0950, -15.9450),
      LatLng(18.0700, -15.9450),
      LatLng(18.0700, -15.9750),
    ],
    labelPosition: LatLng(18.0825, -15.9600),
  ),
  DistrictArea(
    id: 'ksar',
    nameAr: 'لكصر',
    nameFr: 'Ksar',
    polygonPoints: [
      LatLng(18.0900, -15.9450),
      LatLng(18.0900, -15.9200),
      LatLng(18.0650, -15.9200),
      LatLng(18.0650, -15.9450),
    ],
    labelPosition: LatLng(18.0775, -15.9325),
  ),
  DistrictArea(
    id: 'arafat',
    nameAr: 'عرفات',
    nameFr: 'Arafat',
    polygonPoints: [
      LatLng(18.1100, -15.9600),
      LatLng(18.1100, -15.9300),
      LatLng(18.0850, -15.9300),
      LatLng(18.0850, -15.9600),
    ],
    labelPosition: LatLng(18.0975, -15.9450),
  ),
  DistrictArea(
    id: 'riyadh',
    nameAr: 'الرياض',
    nameFr: 'Riyadh',
    polygonPoints: [
      LatLng(18.1050, -15.9900),
      LatLng(18.1050, -15.9600),
      LatLng(18.0800, -15.9600),
      LatLng(18.0800, -15.9900),
    ],
    labelPosition: LatLng(18.0925, -15.9750),
  ),
  DistrictArea(
    id: 'sebkha',
    nameAr: 'السبخة',
    nameFr: 'Sebkha',
    polygonPoints: [
      LatLng(18.0700, -15.9750),
      LatLng(18.0700, -15.9450),
      LatLng(18.0450, -15.9450),
      LatLng(18.0450, -15.9750),
    ],
    labelPosition: LatLng(18.0575, -15.9600),
  ),
  DistrictArea(
    id: 'el_mina',
    nameAr: 'الميناء',
    nameFr: 'El Mina',
    polygonPoints: [
      LatLng(18.0650, -15.9450),
      LatLng(18.0650, -15.9150),
      LatLng(18.0400, -15.9150),
      LatLng(18.0400, -15.9450),
    ],
    labelPosition: LatLng(18.0525, -15.9300),
  ),
  DistrictArea(
    id: 'dar_naim',
    nameAr: 'دار النعيم',
    nameFr: 'Dar Naim',
    polygonPoints: [
      LatLng(18.1200, -15.9400),
      LatLng(18.1200, -15.9100),
      LatLng(18.0950, -15.9100),
      LatLng(18.0950, -15.9400),
    ],
    labelPosition: LatLng(18.1075, -15.9250),
  ),
  DistrictArea(
    id: 'teyaret',
    nameAr: 'تيارات',
    nameFr: 'Teyaret',
    polygonPoints: [
      LatLng(18.1350, -15.9700),
      LatLng(18.1350, -15.9400),
      LatLng(18.1100, -15.9400),
      LatLng(18.1100, -15.9700),
    ],
    labelPosition: LatLng(18.1225, -15.9550),
  ),
  DistrictArea(
    id: 'toujounine',
    nameAr: 'توجنين',
    nameFr: 'Toujounine',
    polygonPoints: [
      LatLng(18.1000, -16.0100),
      LatLng(18.1000, -15.9800),
      LatLng(18.0750, -15.9800),
      LatLng(18.0750, -16.0100),
    ],
    labelPosition: LatLng(18.0875, -15.9950),
  ),
];
