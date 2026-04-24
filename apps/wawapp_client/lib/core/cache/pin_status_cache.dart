import 'package:auth_shared/auth_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for PIN status to improve cold start and offline resilience
///
/// Security: Stores ONLY hasPin/noPin status (never the actual hash)
/// Scope: Per-user cache (keyed by uid)
/// Lifecycle: Cleared on logout and user change
class PinStatusCache {
  static const String _keyPrefix = 'pin_status_';

  /// Get cached PIN status for a user
  ///
  /// Returns null if no cache exists
  static Future<PinStatus?> get(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + uid;
      final cached = prefs.getString(key);

      if (cached == null) return null;

      // Parse cached string to enum
      switch (cached) {
        case 'hasPin':
          return PinStatus.hasPin;
        case 'noPin':
          return PinStatus.noPin;
        default:
          return null;
      }
    } catch (e) {
      // Fail gracefully
      return null;
    }
  }

  /// Store PIN status for a user
  ///
  /// CRITICAL: Only caches hasPin (positive confirmation).
  /// Never persists noPin — it may originate from an empty Firestore local
  /// cache and would poison future cold starts with a false "Create PIN".
  static Future<void> set(String uid, PinStatus status) async {
    try {
      if (status != PinStatus.hasPin) return;

      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + uid;
      await prefs.setString(key, 'hasPin');
    } catch (e) {
      // Fail gracefully - cache is optional
    }
  }

  /// Clear cache for a specific user
  static Future<void> clear(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyPrefix + uid;
      await prefs.remove(key);
    } catch (e) {
      // Fail gracefully
    }
  }

  /// Clear all PIN status caches (for logout)
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      // Fail gracefully
    }
  }
}
