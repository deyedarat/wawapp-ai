import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:io' show Platform;

/// Manages Crashlytics custom keys for context in crash reports
class CrashlyticsKeys {
  static FirebaseCrashlytics? _crashlytics;

  static void initialize(FirebaseCrashlytics crashlytics) {
    _crashlytics = crashlytics;
  }

  // --- Required 7 Custom Keys ---

  static Future<void> setUserId(String? userId) async {
    if (userId != null) {
      await _crashlytics?.setUserIdentifier(userId);
      await _crashlytics?.setCustomKey('user_id', userId);
    }
  }

  static Future<void> setUserRole(String? role) async {
    if (role != null) {
      await _crashlytics?.setCustomKey('user_role', role);
    }
  }

  static Future<void> setAuthState(String state) async {
    await _crashlytics?.setCustomKey('auth_state', state);
  }

  static Future<void> setActiveOrderId(String? orderId) async {
    await _crashlytics?.setCustomKey('active_order_id', orderId ?? 'none');
  }

  static Future<void> setAppVersion(String version) async {
    await _crashlytics?.setCustomKey('app_version', version);
  }

  static Future<void> setPlatform() async {
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : 'unknown';
    await _crashlytics?.setCustomKey('platform', platform);
  }

  static Future<void> setNetworkType(String type) async {
    await _crashlytics?.setCustomKey('network_type', type);
  }

  /// Convenience method to set all user context at once
  static Future<void> setUserContext({
    String? userId,
    String? userRole,
    required String authState,
    String? activeOrderId,
  }) async {
    await setUserId(userId);
    await setUserRole(userRole);
    await setAuthState(authState);
    await setActiveOrderId(activeOrderId);
  }
}
