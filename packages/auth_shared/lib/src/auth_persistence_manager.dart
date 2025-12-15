import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages auth state persistence for Phase 2 resilience (TC-01, TC-03)
class AuthPersistenceManager {
  static const _keyVerificationPending = 'auth_verification_pending';
  static const _keyVerificationPhone = 'auth_verification_phone';
  static const _keyVerificationTimestamp = 'auth_verification_timestamp';
  static const _keyActiveOrderId = 'auth_active_order_id';
  static const _keyActiveOrderStatus = 'auth_active_order_status';

  /// Save verification state when OTP is sent (TC-01)
  static Future<void> saveVerificationPending(String phoneE164) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyVerificationPending, true);
      await prefs.setString(_keyVerificationPhone, phoneE164);
      await prefs.setString(_keyVerificationTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to save verification state: $e');
    }
  }

  /// Clear verification state when OTP is verified or expired
  static Future<void> clearVerificationPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyVerificationPending);
      await prefs.remove(_keyVerificationPhone);
      await prefs.remove(_keyVerificationTimestamp);
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to clear verification state: $e');
    }
  }

  /// Check if verification was interrupted (app was killed during OTP flow)
  static Future<VerificationState?> getInterruptedVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isPending = prefs.getBool(_keyVerificationPending) ?? false;
      
      if (!isPending) return null;

      final phone = prefs.getString(_keyVerificationPhone);
      final timestampStr = prefs.getString(_keyVerificationTimestamp);

      if (phone == null || timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      final age = DateTime.now().difference(timestamp);

      // If verification session is older than 10 minutes, consider it expired
      if (age.inMinutes > 10) {
        await clearVerificationPending();
        return null;
      }

      return VerificationState(
        phoneE164: phone,
        timestamp: timestamp,
      );
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to get interrupted verification: $e');
      return null;
    }
  }

  /// Save active order context for logout recovery (TC-03)
  static Future<void> saveActiveOrder({
    required String orderId,
    required String status,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveOrderId, orderId);
      await prefs.setString(_keyActiveOrderStatus, status);
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to save active order: $e');
    }
  }

  /// Clear active order context
  static Future<void> clearActiveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyActiveOrderId);
      await prefs.remove(_keyActiveOrderStatus);
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to clear active order: $e');
    }
  }

  /// Get active order that existed before logout
  static Future<ActiveOrderState?> getActiveOrderBeforeLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderId = prefs.getString(_keyActiveOrderId);
      final status = prefs.getString(_keyActiveOrderStatus);

      if (orderId == null || status == null) return null;

      return ActiveOrderState(
        orderId: orderId,
        status: status,
      );
    } catch (e) {
      if (kDebugMode) print('[AuthPersistence] Failed to get active order: $e');
      return null;
    }
  }
}

/// Verification state recovered after app kill during OTP flow
class VerificationState {
  final String phoneE164;
  final DateTime timestamp;

  VerificationState({
    required this.phoneE164,
    required this.timestamp,
  });
}

/// Active order state before logout
class ActiveOrderState {
  final String orderId;
  final String status;

  ActiveOrderState({
    required this.orderId,
    required this.status,
  });
}
