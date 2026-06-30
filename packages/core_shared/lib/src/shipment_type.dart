import 'package:flutter/material.dart';

/// Represents the type/category of shipment in a half-truck/pickup cargo delivery.
/// Shared across all WawApp apps (client, driver, admin).
enum ShipmentType {
  lightParcel,
  foodAndPerishables,
  furnitureAndHomeSetup,
  constructionMaterialsAndHeavyLoad,
  electricalAndHomeAppliances,
  generalGoodsAndBoxes,
  fragileOrSensitiveCargo,
}

extension ShipmentTypeExtension on ShipmentType {
  /// Pricing multiplier for this shipment type
  double get multiplier {
    switch (this) {
      case ShipmentType.lightParcel:
        return 0.50;
      case ShipmentType.foodAndPerishables:
        return 1.10;
      case ShipmentType.furnitureAndHomeSetup:
        return 1.30;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return 1.60;
      case ShipmentType.electricalAndHomeAppliances:
        return 1.25;
      case ShipmentType.generalGoodsAndBoxes:
        return 1.00;
      case ShipmentType.fragileOrSensitiveCargo:
        return 1.40;
    }
  }

  /// Arabic label for UI display
  String get arabicLabel {
    switch (this) {
      case ShipmentType.lightParcel:
        return 'رسالة خفيفة';
      case ShipmentType.foodAndPerishables:
        return 'مواد غذائية وسريعة التلف';
      case ShipmentType.furnitureAndHomeSetup:
        return 'أثاث وتجهيزات منزلية';
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return 'مواد بناء وحمولات ثقيلة';
      case ShipmentType.electricalAndHomeAppliances:
        return 'أجهزة كهربائية وكهرومنزلية';
      case ShipmentType.generalGoodsAndBoxes:
        return 'بضائع عامة وكرتون';
      case ShipmentType.fragileOrSensitiveCargo:
        return 'حمولة حساسة / قابلة للكسر';
    }
  }

  /// French label for UI display
  String get frenchLabel {
    switch (this) {
      case ShipmentType.lightParcel:
        return 'Colis léger';
      case ShipmentType.foodAndPerishables:
        return 'Denrées alimentaires et périssables';
      case ShipmentType.furnitureAndHomeSetup:
        return 'Meubles et équipements de maison';
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return 'Matériaux de construction et charges lourdes';
      case ShipmentType.electricalAndHomeAppliances:
        return 'Appareils électriques et électroménagers';
      case ShipmentType.generalGoodsAndBoxes:
        return 'Marchandises générales et cartons';
      case ShipmentType.fragileOrSensitiveCargo:
        return 'Chargement fragile ou sensible';
    }
  }

  /// Icon for UI display
  IconData get icon {
    switch (this) {
      case ShipmentType.lightParcel:
        return Icons.local_shipping;
      case ShipmentType.foodAndPerishables:
        return Icons.restaurant;
      case ShipmentType.furnitureAndHomeSetup:
        return Icons.chair;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return Icons.construction;
      case ShipmentType.electricalAndHomeAppliances:
        return Icons.electrical_services;
      case ShipmentType.generalGoodsAndBoxes:
        return Icons.inventory_2;
      case ShipmentType.fragileOrSensitiveCargo:
        return Icons.warning_amber;
    }
  }

  /// Color for UI display
  Color get color {
    switch (this) {
      case ShipmentType.lightParcel:
        return Colors.teal;
      case ShipmentType.foodAndPerishables:
        return Colors.green;
      case ShipmentType.furnitureAndHomeSetup:
        return Colors.brown;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return Colors.orange;
      case ShipmentType.electricalAndHomeAppliances:
        return Colors.blue;
      case ShipmentType.generalGoodsAndBoxes:
        return Colors.grey;
      case ShipmentType.fragileOrSensitiveCargo:
        return Colors.red;
    }
  }

  /// Firestore string representation
  String get firestoreValue => name;

  /// Parse from Firestore string
  static ShipmentType fromFirestore(String value) {
    return ShipmentType.values.firstWhere((e) => e.name == value, orElse: () => ShipmentType.generalGoodsAndBoxes);
  }

  /// Safe default shipment type
  static ShipmentType get defaultType => ShipmentType.generalGoodsAndBoxes;
}
