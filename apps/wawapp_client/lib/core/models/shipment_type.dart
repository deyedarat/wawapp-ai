import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
  /// Returns the localized label for the shipment type
  String getLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case ShipmentType.foodAndPerishables:
        return l10n.shipmentFoodPerishables;
      case ShipmentType.furnitureAndHomeSetup:
        return l10n.shipmentFurniture;
      case ShipmentType.constructionMaterialsAndHeavyLoad:
        return l10n.shipmentConstruction;
      case ShipmentType.electricalAndHomeAppliances:
        return l10n.shipmentElectrical;
      case ShipmentType.generalGoodsAndBoxes:
        return l10n.shipmentGeneralGoods;
      case ShipmentType.fragileOrSensitiveCargo:
        return l10n.shipmentFragile;
    }
  }
  
  /// Returns the Arabic label (deprecated - use getLabel instead)
  @Deprecated('Use getLabel(context) for proper localization')
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
