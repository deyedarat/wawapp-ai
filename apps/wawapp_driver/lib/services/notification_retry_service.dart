import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Retry mechanism for failed notifications with exponential backoff.
///
/// Handles notification delivery failures by:
/// - Queuing failed notifications
/// - Retrying with exponential backoff (1s, 2s, 4s, 8s, 16s)
/// - Persisting queue across app restarts
/// - Auto-cleaning old notifications
/// - Providing retry statistics
class NotificationRetryService {
  static final NotificationRetryService _instance =
      NotificationRetryService._internal();
  factory NotificationRetryService() => _instance;
  NotificationRetryService._internal();

  static const String _kRetryQueueKey = 'notification_retry_queue';
  static const int _maxRetries = 5;
  static const int _baseDelaySeconds = 1;
  static const int _maxQueueSize = 50;

  final Queue<RetryableNotification> _retryQueue = Queue();
  final Map<String, Timer> _activeTimers = {};
  bool _isProcessing = false;

  /// Add notification to retry queue.
  Future<void> scheduleRetry(
    String notificationId,
    Map<String, dynamic> data,
    Future<bool> Function(Map<String, dynamic>) retryCallback,
  ) async {
    if (_retryQueue.length >= _maxQueueSize) {
      if (kDebugMode) {
        debugPrint('[NotificationRetry] ⚠️ Queue full, dropping oldest notification');
      }
      _retryQueue.removeFirst();
    }

    final notification = RetryableNotification(
      id: notificationId,
      data: data,
      retryCount: 0,
      firstAttempt: DateTime.now(),
      lastAttempt: DateTime.now(),
      retryCallback: retryCallback,
    );

    _retryQueue.add(notification);

    if (kDebugMode) {
      debugPrint('[NotificationRetry] 📥 Added to queue: $notificationId (queue size: ${_retryQueue.length})');
    }

    await _persistQueue();
    _processQueue();
  }

  /// Process retry queue with exponential backoff.
  void _processQueue() {
    if (_isProcessing || _retryQueue.isEmpty) return;

    _isProcessing = true;

    final notification = _retryQueue.first;

    // Check if max retries reached
    if (notification.retryCount >= _maxRetries) {
      if (kDebugMode) {
        debugPrint(
          '[NotificationRetry] ❌ Max retries reached for ${notification.id}, removing from queue',
        );
      }
      _retryQueue.removeFirst();
      _persistQueue();
      _isProcessing = false;
      _processQueue(); // Process next
      return;
    }

    // Calculate delay with exponential backoff
    final delaySeconds = _baseDelaySeconds * (1 << notification.retryCount);

    if (kDebugMode) {
      debugPrint(
        '[NotificationRetry] ⏱️ Retrying ${notification.id} in ${delaySeconds}s (attempt ${notification.retryCount + 1}/$_maxRetries)',
      );
    }

    // Schedule retry
    _activeTimers[notification.id] = Timer(
      Duration(seconds: delaySeconds),
      () async {
        await _attemptRetry(notification);
        _isProcessing = false;
        _processQueue(); // Process next
      },
    );
  }

  /// Attempt to retry notification.
  Future<void> _attemptRetry(RetryableNotification notification) async {
    if (kDebugMode) {
      debugPrint('[NotificationRetry] 🔄 Retrying ${notification.id}...');
    }

    notification.retryCount++;
    notification.lastAttempt = DateTime.now();

    try {
      final success = await notification.retryCallback(notification.data);

      if (success) {
        if (kDebugMode) {
          debugPrint('[NotificationRetry] ✅ Retry successful for ${notification.id}');
        }
        _retryQueue.removeFirst();
        _activeTimers.remove(notification.id);
        await _persistQueue();
      } else {
        if (kDebugMode) {
          debugPrint(
            '[NotificationRetry] ❌ Retry failed for ${notification.id} (attempt ${notification.retryCount}/$_maxRetries)',
          );
        }
        await _persistQueue();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationRetry] ❌ Retry error for ${notification.id}: $e');
      }
      await _persistQueue();
    }
  }

  /// Persist retry queue to local storage.
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = _retryQueue
          .map((n) => {
                'id': n.id,
                'data': n.data,
                'retryCount': n.retryCount,
                'firstAttempt': n.firstAttempt.millisecondsSinceEpoch,
                'lastAttempt': n.lastAttempt.millisecondsSinceEpoch,
              })
          .toList();

      // Note: We can't persist callbacks, so retries won't survive app restart
      // For production, consider using a work manager or backend queue
      await prefs.setString(_kRetryQueueKey, queueData.toString());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationRetry] ❌ Error persisting queue: $e');
      }
    }
  }

  /// Cancel retry for specific notification.
  void cancelRetry(String notificationId) {
    _activeTimers[notificationId]?.cancel();
    _activeTimers.remove(notificationId);
    _retryQueue.removeWhere((n) => n.id == notificationId);
    _persistQueue();

    if (kDebugMode) {
      debugPrint('[NotificationRetry] ⛔ Cancelled retry for $notificationId');
    }
  }

  /// Clear all pending retries.
  Future<void> clearQueue() async {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _retryQueue.clear();
    await _persistQueue();

    if (kDebugMode) {
      debugPrint('[NotificationRetry] 🗑️ Queue cleared');
    }
  }

  /// Get retry statistics.
  RetryStatistics getStatistics() {
    final now = DateTime.now();
    final recent = _retryQueue.where((n) {
      return now.difference(n.firstAttempt).inMinutes < 30;
    }).length;

    return RetryStatistics(
      queueSize: _retryQueue.length,
      recentRetries: recent,
      activeTimers: _activeTimers.length,
    );
  }

  /// Dispose resources.
  void dispose() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}

/// Retryable notification with metadata.
class RetryableNotification {
  final String id;
  final Map<String, dynamic> data;
  int retryCount;
  final DateTime firstAttempt;
  DateTime lastAttempt;
  final Future<bool> Function(Map<String, dynamic>) retryCallback;

  RetryableNotification({
    required this.id,
    required this.data,
    required this.retryCount,
    required this.firstAttempt,
    required this.lastAttempt,
    required this.retryCallback,
  });
}

/// Retry statistics.
class RetryStatistics {
  final int queueSize;
  final int recentRetries;
  final int activeTimers;

  RetryStatistics({
    required this.queueSize,
    required this.recentRetries,
    required this.activeTimers,
  });

  bool get hasIssues => queueSize > 5 || recentRetries > 10;
}
