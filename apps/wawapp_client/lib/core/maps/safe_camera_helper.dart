import 'dart:async';

import 'package:core_shared/core_shared.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Safe wrapper for Google Maps camera operations to prevent channel-error crashes
class SafeCameraHelper {
  static const String _tag = 'SafeCameraHelper';

  /// Safely animate camera with proper error handling and state checks
  static Future<void> animateCamera({
    required GoogleMapController? controller,
    required CameraUpdate cameraUpdate,
    required bool mounted,
    String? screenName,
    String? action,
  }) async {
    final mapReady = controller != null;
    final controllerReady = mapReady;

    CrashlyticsObserver.logMapOperation(
      action: action ?? 'animate',
      mapReady: mapReady,
      controllerReady: controllerReady,
      screen: screenName,
    );

    // Guard: Check if widget is still mounted
    if (!mounted) return;

    // Guard: Check if controller is available
    if (controller == null) return;

    try {
      await controller.animateCamera(cameraUpdate);
    } catch (e, stackTrace) {
      // Log non-fatal error to Crashlytics with context
      FirebaseCrashlytics.instance.recordError(
        e,
        stackTrace,
        fatal: false,
        information: [
          'Screen: ${screenName ?? 'unknown'}',
          'Action: ${action ?? 'unknown'}',
        ],
      );

      debugPrint('[$_tag] Camera animation failed: $e');
    }
  }

  /// Schedule camera operation after current frame to avoid build-time calls
  static void scheduleAfterFrame({
    required VoidCallback operation,
    required bool mounted,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        operation();
      }
    });
  }
}

/// Mixin to provide safe camera operations to StatefulWidgets with GoogleMaps
mixin SafeCameraMixin<T extends StatefulWidget> on State<T> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controllerCompleter = Completer();
  bool _mapReady = false;

  /// Get the map controller safely
  GoogleMapController? get mapController => _mapController;

  /// Check if map is ready for camera operations
  bool get isMapReady => _mapReady && _mapController != null;

  /// Handle map creation with proper initialization
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _mapReady = true;

    if (!_controllerCompleter.isCompleted) {
      _controllerCompleter.complete(controller);
    }

    // Set Crashlytics context
    FirebaseCrashlytics.instance.setCustomKey('map_ready', 'true');
    FirebaseCrashlytics.instance.setCustomKey('screen', runtimeType.toString());
  }

  /// Safely animate camera with all safety checks
  Future<void> safeAnimateCamera(
    CameraUpdate cameraUpdate, {
    String? action,
  }) async {
    await SafeCameraHelper.animateCamera(
      controller: _mapController,
      cameraUpdate: cameraUpdate,
      mounted: mounted,
      screenName: runtimeType.toString(),
      action: action,
    );
  }

  /// Schedule camera operation after frame
  void scheduleCameraOperation(VoidCallback operation) {
    SafeCameraHelper.scheduleAfterFrame(
      operation: operation,
      mounted: mounted,
    );
  }

  /// Wait for map to be ready before performing operations
  Future<void> whenMapReady(VoidCallback operation) async {
    if (isMapReady) {
      operation();
    } else {
      try {
        await _controllerCompleter.future;
        if (mounted) {
          operation();
        }
      } catch (e) {
        debugPrint('[SafeCameraMixin] Map ready timeout: $e');
      }
    }
  }

  @override
  void dispose() {
    _mapController = null;
    _mapReady = false;
    FirebaseCrashlytics.instance.setCustomKey('map_ready', 'false');
    super.dispose();
  }
}
