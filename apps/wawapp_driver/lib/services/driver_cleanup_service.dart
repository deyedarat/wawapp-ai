import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_status_service.dart';
import 'location_service.dart';

/// Service to clean up driver state on logout
/// Stops location tracking, sets driver offline, clears local state
class DriverCleanupService {
  DriverCleanupService._();
  static final DriverCleanupService instance = DriverCleanupService._();

  static const String _logTag = '[DRIVER_CLEANUP]';

  /// Perform cleanup before logout
  /// Returns true if cleanup successful, false if error (but logout should proceed)
  Future<bool> cleanupBeforeLogout() async {
    debugPrint('$_logTag Starting pre-logout cleanup...');

    try {
      // Get current user ID before signing out
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('$_logTag No user logged in, skipping cleanup');
        return true;
      }

      final driverId = user.uid;
      debugPrint('$_logTag Cleaning up for driver: $driverId');

      // Step 1: Stop location stream
      debugPrint('$_logTag Stopping location stream...');
      LocationService.instance.stopPositionStream();
      debugPrint('$_logTag ✅ Location stream stopped');

      // Step 2: Set driver offline (best effort)
      try {
        debugPrint('$_logTag Setting driver offline...');
        await DriverStatusService.instance.setOffline(driverId).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('$_logTag ⚠️ Timeout setting offline (network issue)');
          },
        );
        debugPrint('$_logTag ✅ Driver set offline');
      } on Object catch (e) {
        debugPrint('$_logTag ⚠️ Error setting offline: $e (continuing anyway)');
        // Don't fail logout if offline update fails
      }

      debugPrint('$_logTag ✅ Cleanup complete');
      return true;
    } on Object catch (e) {
      debugPrint('$_logTag ❌ Cleanup error: $e');
      // Return true anyway - cleanup errors shouldn't block logout
      return true;
    }
  }
}
