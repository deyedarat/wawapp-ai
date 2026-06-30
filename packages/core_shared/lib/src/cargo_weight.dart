/// Cargo weight categories for shipment pricing.
import 'package:flutter/material.dart';

enum CargoWeight { halfTon, oneTon, oneAndHalfTon, twoTons }

extension CargoWeightExtension on CargoWeight {
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

  static CargoWeight get defaultWeight => CargoWeight.halfTon;

  static CargoWeight fromTons(double tons) {
    if (tons <= 0.5) return CargoWeight.halfTon;
    if (tons <= 1.0) return CargoWeight.oneTon;
    if (tons <= 1.5) return CargoWeight.oneAndHalfTon;
    return CargoWeight.twoTons;
  }
}
