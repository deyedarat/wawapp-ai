import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationLogger {
  static final NotificationLogger instance = NotificationLogger._();
  NotificationLogger._();

  final _firestore = FirebaseFirestore.instance;

  Future<void> log({
    required String eventType,
    required String notificationType,
    required String appState,
    String? displayMode,
    String? orderId,
    String? escalationLevel,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint(
        '[NotificationLogger] log() called — uid=$uid, event=$eventType, type=$notificationType, state=$appState');
    if (uid == null) {
      debugPrint('[NotificationLogger] uid is null — skipping write');
      return;
    }
    try {
      await _firestore
          .collection('notification_logs')
          .doc(uid)
          .collection('events')
          .add({
        'eventType': eventType,
        'notificationType': notificationType,
        'appState': appState,
        if (displayMode != null) 'displayMode': displayMode,
        if (orderId != null) 'orderId': orderId,
        if (escalationLevel != null) 'escalationLevel': escalationLevel,
        'androidVersion': Platform.operatingSystemVersion,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint(
          '[NotificationLogger] ✅ Written to notification_logs/$uid/events');
    } on Object catch (e) {
      debugPrint('[NotificationLogger] ❌ Failed to log: $e');
    }
  }
}
