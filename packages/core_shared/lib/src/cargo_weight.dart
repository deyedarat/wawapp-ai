import 'package:flutter/material.dart';

/// Cargo weight categories for WawApp deliveries.
/// Shared across all apps (client, driver, admin).
enum CargoWeight { halfTon, oneTon, oneAndHalfTon, twoTons }

extension CargoWeightExtension on CargoWeight {
  /// Weight value in tons
  double get tons {
    switch (this) {
      case CargoWeight.halfTon:
        return 0.5;
      case CargoWeight.oneTon:
        return 1.0;
      case CargoWeight.oneAndHalfTon:
        return 1.5;
      case CargoWeight.twoTons:
        return 2.0;
    }
  }

  /// Cost in MRU for this weight category
  int get costMRU {
    switch (this) {
      case CargoWeight.halfTon:
        return 70;
      case CargoWeight.oneTon:
        return 140;
      case CargoWeight.oneAndHalfTon:
        return 210;
      case CargoWeight.twoTons:
        return 280;
    }
  }

  /// Arabic label for UI display
  String get arabicLabel {
    switch (this) {
      case CargoWeight.halfTon:
        return 'نصف طن';
      case CargoWeight.oneTon:
        return 'طن';
      case CargoWeight.oneAndHalfTon:
        return 'طن ونصف';
      case CargoWeight.twoTons:
        return 'طنان';
    }
  }

  /// French label for UI display
  String get frenchLabel {
    switch (this) {
      case CargoWeight.halfTon:
        return 'Demi-tonne';
      case CargoWeight.oneTon:
        return 'Une tonne';
      case CargoWeight.oneAndHalfTon:
        return 'Tonne et demie';
      case CargoWeight.twoTons:
        return 'Deux tonnes';
    }
  }

  /// Icon for UI display
  IconData get icon {
    switch (this) {
      case CargoWeight.halfTon:
        return Icons.fitness_center;
      case CargoWeight.oneTon:
        return Icons.scale;
      case CargoWeight.oneAndHalfTon:
        return Icons.scale;
      case CargoWeight.twoTons:
        return Icons.local_shipping;
    }
  }

  /// Default weight
  static CargoWeight get defaultWeight => CargoWeight.halfTon;

  /// Parse from tons value
  static CargoWeight fromTons(double tons) {
    if (tons <= 0.5) return CargoWeight.halfTon;
    if (tons <= 1.0) return CargoWeight.oneTon;
    if (tons <= 1.5) return CargoWeight.oneAndHalfTon;
    return CargoWeight.twoTons;
  }
}
