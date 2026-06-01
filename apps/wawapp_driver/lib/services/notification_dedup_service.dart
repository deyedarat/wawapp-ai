import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'notification_dedup_service.g.dart';

const _prefsKey = 'notification_dedup_ids';
const _maxAge = Duration(hours: 24);

class NotificationDedupService {
  NotificationDedupService(this._prefs) {
    _load();
    _cleanup();
  }

  final SharedPreferences _prefs;

  /// messageId → timestamp (millisecondsSinceEpoch)
  Map<String, int> _processed = {};

  bool isDuplicate(String messageId) => _processed.containsKey(messageId);

  void markAsProcessed(String messageId) {
    _processed[messageId] = DateTime.now().millisecondsSinceEpoch;
    _save();
  }

  /// Remove a single key so a snoozed offer can pass dedup again.
  void clearProcessed(String messageId) {
    if (_processed.remove(messageId) != null) _save();
  }

  void _load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _processed = Map<String, int>.from(jsonDecode(raw) as Map);
      } catch (e) {
        if (kDebugMode) debugPrint('[NotificationDedup] ❌ Parse error: $e');
        _processed = {};
      }
    }
  }

  void _cleanup() {
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - _maxAge.inMilliseconds;
    final before = _processed.length;
    _processed.removeWhere((_, ts) => ts < cutoff);
    if (_processed.length != before) {
      if (kDebugMode) {
        debugPrint(
            '[NotificationDedup] 🧹 Cleaned ${before - _processed.length} stale entries');
      }
      _save();
    }
  }

  void _save() {
    _prefs.setString(_prefsKey, jsonEncode(_processed));
  }
}

@riverpod
NotificationDedupService notificationDedup(NotificationDedupRef ref) {
  throw UnimplementedError(
    'notificationDedupProvider must be overridden with a SharedPreferences instance',
  );
}
