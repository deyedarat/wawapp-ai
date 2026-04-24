import 'package:auth_shared/auth_shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for PIN status to improve cold start and offline resilience
class PinStatusCache {
  static const String _keyPrefix = 'pin_status_';

  static Future<PinStatus?> get(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyPrefix + uid);
      if (cached == null) return null;
      switch (cached) {
        case 'hasPin':
          return PinStatus.hasPin;
        case 'noPin':
          return PinStatus.noPin;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String uid, PinStatus status) async {
    try {
      // CRITICAL: Only cache hasPin (positive confirmation).
      // Never persist noPin — it may come from an empty Firestore cache
      // and would poison future cold starts.
      if (status != PinStatus.hasPin) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPrefix + uid, 'hasPin');
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
