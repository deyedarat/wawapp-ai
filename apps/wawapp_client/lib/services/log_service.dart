import 'dart:developer' as dev;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Singleton structured logging service.
///
/// – Maintains a circular buffer of the last [_maxSize] log lines in memory.
/// – Uses dart:developer log() for every entry (visible in IDE / release logs).
/// – Selectively logs to Crashlytics:
///     • log() breadcrumb only for key lifecycle events
///     • recordError() (non-fatal) only when an errorCode is present (failure path)
/// – NEVER logs: full phone numbers, OTP codes, verificationId, or tokens.
class LogService {
  LogService._();
  static final LogService instance = LogService._();

  static const int _maxSize = 50;
  final List<String> _buffer = [];

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Returns a copy of the in-memory log buffer (last 50 entries).
  List<String> get logs => List.unmodifiable(_buffer);

  /// Masks a phone number for safe logging.
  /// E.g. "+22245678901" → "+222******901"
  /// Falls back gracefully for short / empty values.
  String maskPhone(String phone) {
    if (phone.isEmpty) return '***';
    // Preserve country code prefix (up to 4 chars, e.g. "+222") and last 3 digits.
    final clean = phone.replaceAll(' ', '');
    if (clean.length <= 7) return '${clean.substring(0, 1)}******';
    final prefix = clean.substring(0, 4); // e.g. "+222"
    final suffix = clean.substring(clean.length - 3); // last 3 digits
    return '$prefix******$suffix';
  }

  /// Records a structured log entry.
  ///
  /// [event] – machine-readable event name (e.g. 'otp_sent', 'verification_failed')
  /// [phone] – raw phone string; will be auto-masked before storage
  /// [errorCode] – Firebase error code, if applicable
  /// [errorMessage] – human-readable (not shown to user) error detail
  void addLog({
    required String event,
    String? phone,
    String? errorCode,
    String? errorMessage,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final maskedPhone = phone != null ? maskPhone(phone) : null;

    final parts = [
      '[$timestamp]',
      'event=$event',
      if (maskedPhone != null) 'phone=$maskedPhone',
      if (errorCode != null) 'code=$errorCode',
      if (errorMessage != null) 'msg=$errorMessage',
    ];
    final line = parts.join(' | ');

    // 1. Always: in-memory circular buffer
    _addToBuffer(line);

    // 2. Always: dart:developer (visible in IDE and release logs via logcat)
    dev.log(line, name: 'LogService');

    // 3. Selective Crashlytics — only for important lifecycle events
    _logToCrashlytics(event: event, line: line, errorCode: errorCode, errorMessage: errorMessage);
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  void _addToBuffer(String line) {
    if (_buffer.length >= _maxSize) {
      _buffer.removeAt(0); // drop oldest
    }
    _buffer.add(line);
  }

  static const _crashlyticsKeyEvents = {
    'otp_sent',
    'otp_verified',
    'verification_failed',
    'otp_send_start',
    'bug_report_submitted',
  };

  void _logToCrashlytics({
    required String event,
    required String line,
    String? errorCode,
    String? errorMessage,
  }) {
    try {
      if (errorCode != null) {
        // Failure path: record as non-fatal error so it surfaces in Crashlytics
        FirebaseCrashlytics.instance.recordError(
          Exception(errorMessage ?? event),
          null,
          reason: 'event=$event code=$errorCode',
          fatal: false,
          printDetails: false,
        );
      } else if (_crashlyticsKeyEvents.contains(event)) {
        // Key lifecycle event: add as breadcrumb only
        FirebaseCrashlytics.instance.log(line);
      }
      // All other events stay in memory only — no Crashlytics spam
    } catch (_) {
      // Never let logging crash the app
    }
  }
}
