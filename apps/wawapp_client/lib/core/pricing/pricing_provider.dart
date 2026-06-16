import 'dart:async';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the active pricing config from Firestore `pricing_configs` collection.
///
/// Reads the first document where `isActive == true` and loads its values
/// into [PricingConfig] via [PricingConfig.loadFromMap].
///
/// If no active config exists, defaults remain in effect.
final pricingConfigProvider = StreamProvider<void>((ref) {
  final controller = StreamController<void>();

  final subscription = FirebaseFirestore.instance
      .collection('pricing_configs')
      .where('isActive', isEqualTo: true)
      .limit(1)
      .snapshots()
      .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final data = snapshot.docs.first.data();
            PricingConfig.loadFromMap(data);
            dev.log(
              '[PricingProvider] Loaded remote config: '
              'base=${PricingConfig.base}, perKm=${PricingConfig.perKm}, '
              'minFare=${PricingConfig.minFare}, '
              'antigravity=${PricingConfig.antigravityMultiplier}',
            );
          } else {
            // No active config — keep defaults
            dev.log('[PricingProvider] No active pricing config found, using defaults');
          }
          controller.add(null);
        },
        onError: (e) {
          dev.log('[PricingProvider] Error loading pricing config: $e');
          controller.addError(e);
        },
      );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Eagerly initializes pricing config at app startup.
///
/// Call this once in your app's initialization (e.g., in main or a splash screen)
/// to ensure pricing values are loaded before the user sees prices.
Future<void> initPricingConfig() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('pricing_configs')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      PricingConfig.loadFromMap(snapshot.docs.first.data());
      dev.log(
        '[PricingConfig] Initialized from Firestore: '
        'base=${PricingConfig.base}, perKm=${PricingConfig.perKm}, '
        'minFare=${PricingConfig.minFare}, '
        'antigravity=${PricingConfig.antigravityMultiplier}',
      );
    } else {
      dev.log('[PricingConfig] No active config, using hardcoded defaults');
    }
  } catch (e) {
    dev.log('[PricingConfig] Failed to load from Firestore, using defaults: $e');
  }
}
