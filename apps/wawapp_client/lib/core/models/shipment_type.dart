import 'package:flutter/material.dart';

/// Represents the type/category of shipment in a half-truck/pickup cargo delivery
enum ShipmentType {
  foodAndPerishables,
  furnitureAndHomeSetup,
  constructionMaterialsAndHeavyLoad,
  electricalAndHomeAppliances,
  generalGoodsAndBoxes,
  fragileOrSensitiveCargo,
}

extension ShipmentTypeExtension on ShipmentType {
  /// Returns the Arabic label for the shipment type
  String get arabicLabel {
    switch (this) {
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

  /// Returns the French label for the shipment type
  String get frenchLabel {
    switch (this) {
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

  /// Returns the icon data for the shipment type
  IconData get icon {
    switch (this) {
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

  /// Returns a color associated with the shipment type
  Color get color {
    switch (this) {
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

  /// Safe default shipment type
  static ShipmentType get defaultType => ShipmentType.generalGoodsAndBoxes;
}
