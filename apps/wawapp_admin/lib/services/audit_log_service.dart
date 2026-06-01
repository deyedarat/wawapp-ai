/// Audit Log Service
/// Records and retrieves admin actions for accountability and governance
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Represents a single audit log entry
class AuditLogEntry {
  final String id;
  final String action;
  final String category;
  final String adminUid;
  final String adminEmail;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  AuditLogEntry({
    required this.id,
    required this.action,
    required this.category,
    required this.adminUid,
    required this.adminEmail,
    this.targetId,
    this.targetType,
    this.details,
    required this.createdAt,
  });

  factory AuditLogEntry.fromFirestore(String id, Map<String, dynamic> data) {
    return AuditLogEntry(
      id: id,
      action: data['action'] as String? ?? '',
      category: data['category'] as String? ?? 'other',
      adminUid: data['adminUid'] as String? ?? '',
      adminEmail: data['adminEmail'] as String? ?? '',
      targetId: data['targetId'] as String?,
      targetType: data['targetType'] as String?,
      details: data['details'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Human-readable action label in Arabic
  String get actionLabel {
    switch (action) {
      case 'driver_verified':
        return 'توثيق سائق';
      case 'driver_unverified':
        return 'إلغاء توثيق سائق';
      case 'driver_blocked':
        return 'حظر سائق';
      case 'driver_unblocked':
        return 'إلغاء حظر سائق';
      case 'driver_balance_added':
        return 'إضافة رصيد لسائق';
      case 'order_cancelled':
        return 'إلغاء طلب';
      case 'order_reassigned':
        return 'إعادة تعيين طلب';
      case 'order_created_manual':
        return 'إنشاء طلب يدوي';
      case 'client_blocked':
        return 'حظر عميل';
      case 'client_unblocked':
        return 'إلغاء حظر عميل';
      case 'settings_updated':
        return 'تحديث الإعدادات';
      case 'admin_login':
        return 'تسجيل دخول';
      case 'admin_logout':
        return 'تسجيل خروج';
      default:
        return action;
    }
  }

  /// Category label in Arabic
  String get categoryLabel {
    switch (category) {
      case 'driver':
        return 'السائقون';
      case 'order':
        return 'الطلبات';
      case 'client':
        return 'العملاء';
      case 'finance':
        return 'المالية';
      case 'settings':
        return 'الإعدادات';
      case 'auth':
        return 'المصادقة';
      default:
        return 'أخرى';
    }
  }
}

/// Service for recording and querying audit logs
class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _collection => _firestore.collection('admin_audit_log');

  /// Record an admin action
  Future<void> log({
    required String action,
    required String category,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? details,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _collection.add({
        'action': action,
        'category': category,
        'adminUid': user.uid,
        'adminEmail': user.email ?? 'unknown',
        'targetId': targetId,
        'targetType': targetType,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        print('AuditLogService.log error: $e');
      }
    }
  }

  /// Get audit log stream with optional filters
  Stream<List<AuditLogEntry>> getAuditLogStream({String? categoryFilter, int limit = 100}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('createdAt', descending: true).limit(limit);

    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      query = query.where('category', isEqualTo: categoryFilter);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AuditLogEntry.fromFirestore(doc.id, doc.data())).toList();
    });
  }

  /// Get recent activity for dashboard (last N entries)
  Stream<List<AuditLogEntry>> getRecentActivity({int limit = 10}) {
    return _collection.orderBy('createdAt', descending: true).limit(limit).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => AuditLogEntry.fromFirestore(doc.id, doc.data())).toList();
    });
  }
}
