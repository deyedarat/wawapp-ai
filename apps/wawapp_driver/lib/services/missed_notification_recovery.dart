import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Firestore-based missed notification recovery system.
///
/// When notifications fail to deliver via FCM (network issues, device off, etc.),
/// this service:
/// - Polls Firestore for missed notifications
/// - Recovers and displays them when app comes online
/// - Marks notifications as delivered
/// - Prevents duplicate deliveries
///
/// Backend should write notifications to Firestore in addition to sending FCM.
class MissedNotificationRecovery {
  static final MissedNotificationRecovery _instance =
      MissedNotificationRecovery._internal();
  factory MissedNotificationRecovery() => _instance;
  MissedNotificationRecovery._internal();

  static const String _kLastRecoveryCheckKey = 'last_recovery_check';
  static const String _kRecoveredNotificationsKey = 'recovered_notifications';
  static const Duration _recoveryInterval = Duration(minutes: 2);

  Timer? _recoveryTimer;
  StreamSubscription<QuerySnapshot>? _notificationSubscription;
  final Set<String> _recoveredIds = {};

  /// Start missed notification recovery service.
  Future<void> start() async {
    if (kDebugMode) {
      debugPrint(
          '[MissedNotificationRecovery] 🚀 Starting recovery service...');
    }

    // Load previously recovered IDs to prevent duplicates
    await _loadRecoveredIds();

    // Start periodic polling
    _startPeriodicRecovery();

    // Also listen to real-time changes (more efficient than polling)
    _startRealtimeListener();

    if (kDebugMode) {
      debugPrint('[MissedNotificationRecovery] ✅ Recovery service started');
    }
  }

  /// Start periodic recovery check (fallback if realtime fails).
  void _startPeriodicRecovery() {
    _recoveryTimer?.cancel();
    _recoveryTimer = Timer.periodic(_recoveryInterval, (_) async {
      await _checkForMissedNotifications();
    });
  }

  /// Start real-time listener for new notifications.
  void _startRealtimeListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _notificationSubscription?.cancel();

    // PATCH-08 (RC-12): Without a createdAt lower-bound the listener would fire
    // for every undelivered doc ever written, including offers for orders that
    // are already expired/accepted. Mirror the same 24-hour cutoff the polling
    // path uses so stale notifications are never recovered.
    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    // Listen to driver-specific notification collection
    _notificationSubscription = FirebaseFirestore.instance
        .collection('driver_notifications')
        .where('driverId', isEqualTo: user.uid)
        .where('delivered', isEqualTo: false)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docChanges.isEmpty) return;

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            _processNotification(change.doc);
          }
        }
      },
      onError: (error) {
        if (kDebugMode) {
          debugPrint('[MissedNotificationRecovery] ❌ Listener error: $error');
        }
      },
    );
  }


  /// Check for missed notifications (polling mode).
  Future<void> _checkForMissedNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Query notifications from last 24 hours that weren't delivered
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      final snapshot = await FirebaseFirestore.instance
          .collection('driver_notifications')
          .where('driverId', isEqualTo: user.uid)
          .where('delivered', isEqualTo: false)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(cutoff))
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('[MissedNotificationRecovery] ✅ No missed notifications');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint(
          '[MissedNotificationRecovery] 📥 Found ${snapshot.docs.length} missed notifications',
        );
      }

      for (final doc in snapshot.docs) {
        await _processNotification(doc);
      }

      await _saveLastCheckTimestamp();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MissedNotificationRecovery] ❌ Recovery check failed: $e');
      }
    }
  }

  /// Process a single notification document.
  Future<void> _processNotification(DocumentSnapshot doc) async {
    final notificationId = doc.id;

    // Skip if already recovered
    if (_recoveredIds.contains(notificationId)) {
      return;
    }

    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;

      final notificationType = data['notificationType'] as String?;
      final orderId = data['orderId'] as String?;

      if (kDebugMode) {
        debugPrint('[FORENSIC_TRACE] MissedNotificationRecovery TRAP. Recovering notification: $notificationId ($notificationType) from order $orderId');
      }

      NotificationService().recoverNotification(data);
      await _markAsDelivered(notificationId);

      // Track as recovered
      _recoveredIds.add(notificationId);
      await _saveRecoveredIds();

      if (kDebugMode) {
        debugPrint('[MissedNotificationRecovery] ✅ Recovered: $notificationId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MissedNotificationRecovery] ❌ Error processing notification $notificationId: $e',
        );
      }
    }
  }

  /// Mark notification as delivered in Firestore.
  Future<void> _markAsDelivered(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('driver_notifications')
          .doc(notificationId)
          .update({
        'delivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[MissedNotificationRecovery] ❌ Error marking as delivered: $e',
        );
      }
    }
  }

  /// Load previously recovered notification IDs.
  Future<void> _loadRecoveredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recovered = prefs.getStringList(_kRecoveredNotificationsKey) ?? [];
      _recoveredIds.addAll(recovered);

      // Clean up old IDs (keep last 100)
      if (_recoveredIds.length > 100) {
        final toRemove = _recoveredIds.length - 100;
        _recoveredIds.removeAll(_recoveredIds.take(toRemove));
        await _saveRecoveredIds();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[MissedNotificationRecovery] ❌ Error loading recovered IDs: $e');
      }
    }
  }

  /// Save recovered notification IDs.
  Future<void> _saveRecoveredIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kRecoveredNotificationsKey,
        _recoveredIds.toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[MissedNotificationRecovery] ❌ Error saving recovered IDs: $e');
      }
    }
  }

  /// Save last check timestamp.
  Future<void> _saveLastCheckTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kLastRecoveryCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[MissedNotificationRecovery] ❌ Error saving timestamp: $e');
      }
    }
  }

  /// Get recovery statistics.
  Future<RecoveryStatistics> getStatistics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheckTimestamp = prefs.getInt(_kLastRecoveryCheckKey);
      final lastCheck = lastCheckTimestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(lastCheckTimestamp)
          : null;

      return RecoveryStatistics(
        recoveredCount: _recoveredIds.length,
        lastCheck: lastCheck,
        isActive: _recoveryTimer?.isActive ?? false,
      );
    } catch (e) {
      return RecoveryStatistics(
        recoveredCount: 0,
        lastCheck: null,
        isActive: false,
      );
    }
  }

  /// Force immediate recovery check.
  Future<void> forceRecovery() async {
    if (kDebugMode) {
      debugPrint('[MissedNotificationRecovery] 🔄 Force recovery requested');
    }
    await _checkForMissedNotifications();
  }

  /// Stop recovery service.
  void stop() {
    _recoveryTimer?.cancel();
    _notificationSubscription?.cancel();

    if (kDebugMode) {
      debugPrint('[MissedNotificationRecovery] ⛔ Recovery service stopped');
    }
  }

  /// Dispose resources.
  void dispose() {
    stop();
  }
}

/// Recovery statistics.
class RecoveryStatistics {
  final int recoveredCount;
  final DateTime? lastCheck;
  final bool isActive;

  RecoveryStatistics({
    required this.recoveredCount,
    required this.lastCheck,
    required this.isActive,
  });

  String get lastCheckFormatted {
    if (lastCheck == null) return 'Never';
    final diff = DateTime.now().difference(lastCheck!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
