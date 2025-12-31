import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _lastPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();

  static const String _logTag = '[LOCATION_SERVICE]';

  /// Check if location services (GPS) are enabled on the device
  Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (kDebugMode) {
      debugPrint('$_logTag GPS/Location services enabled: $enabled');
    }
    return enabled;
  }

  /// Check and request location permission
  Future<LocationPermission> checkAndRequestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (kDebugMode) {
      debugPrint('$_logTag Current permission: $permission');
    }

    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        debugPrint('$_logTag Requesting permission...');
      }
      permission = await Geolocator.requestPermission();
      if (kDebugMode) {
        debugPrint('$_logTag Permission after request: $permission');
      }
    }

    return permission;
  }

  /// Verify all location prerequisites are met before going online
  /// Returns error message if any check fails, null if all checks pass
  Future<String?> verifyLocationPrerequisites() async {
    if (kDebugMode) {
      debugPrint('$_logTag Verifying location prerequisites...');
    }

    // Check 1: Location services enabled (GPS ON)
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ GPS/Location services are disabled');
      }
      return 'GPS is disabled. Please enable location services in device settings.';
    }
    if (kDebugMode) {
      debugPrint('$_logTag ✅ GPS/Location services enabled');
    }

    // Check 2: Permission granted
    final permission = await checkAndRequestPermission();
    if (permission == LocationPermission.denied) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Location permission denied');
      }
      return 'Location permission denied. Please grant permission to go online.';
    }
    if (permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Location permission denied forever');
      }
      return 'Location permission denied permanently. Please enable in app settings.';
    }
    if (kDebugMode) {
      debugPrint('$_logTag ✅ Location permission granted');
    }

    if (kDebugMode) {
      debugPrint('$_logTag ✅ All prerequisites verified');
    }
    return null; // All checks passed
  }

  /// Get current position with timeout
  /// This is used for the "first fix guarantee" when going online
  Future<Position> getCurrentPosition({Duration timeout = const Duration(seconds: 20)}) async {
    if (kDebugMode) {
      debugPrint('$_logTag Getting current position (timeout: ${timeout.inSeconds}s)...');
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Location services disabled');
      }
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Location permission denied');
      }
      throw const PermissionDeniedException('Location permission denied');
    }

    try {
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(timeout);

      if (kDebugMode) {
        debugPrint('$_logTag ✅ Got position: lat=${_lastPosition!.latitude}, lng=${_lastPosition!.longitude}, accuracy=${_lastPosition!.accuracy}m');
      }
      return _lastPosition!;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Timeout getting position after ${timeout.inSeconds}s');
      }
      throw TimeoutException('Could not obtain GPS fix within ${timeout.inSeconds} seconds. Please ensure you have clear sky view.');
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('$_logTag ❌ Error getting position: $e');
      }
      rethrow;
    }
  }

  /// Start listening to position stream with error handling
  /// This provides continuous location updates
  void startPositionStream({
    required Function(Position) onPosition,
    required Function(Object) onError,
  }) {
    if (kDebugMode) {
      debugPrint('$_logTag Starting position stream...');
    }

    _positionStreamSubscription?.cancel();

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Only emit when moved 50+ meters (Memory Optimization Phase 1)
    );

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        if (kDebugMode) {
          debugPrint('$_logTag Stream update: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');
        }
        _lastPosition = position;
        _positionController.add(position);
        onPosition(position);
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('$_logTag ❌ Stream error: $error');
        }

        if (error is LocationServiceDisabledException) {
          if (kDebugMode) {
            debugPrint('$_logTag Location services were disabled');
          }
          onError('GPS was disabled. Please re-enable location services.');
        } else if (error is PermissionDeniedException) {
          if (kDebugMode) {
            debugPrint('$_logTag Permission was denied');
          }
          onError('Location permission was denied.');
        } else {
          if (kDebugMode) {
            debugPrint('$_logTag Unknown error: $error');
          }
          onError('Location error: $error');
        }
      },
      cancelOnError: false, // Keep stream alive even after errors
    );

    if (kDebugMode) {
      debugPrint('$_logTag Position stream started');
    }
  }

  /// Stop position stream
  void stopPositionStream() {
    if (kDebugMode) {
      debugPrint('$_logTag Stopping position stream...');
    }
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    if (kDebugMode) {
      debugPrint('$_logTag Position stream stopped');
    }
  }

  Position? get lastPosition => _lastPosition;

  Stream<Position> get positionStream => _positionController.stream;

  void dispose() {
    stopPositionStream();
    _positionController.close();
  }
}
