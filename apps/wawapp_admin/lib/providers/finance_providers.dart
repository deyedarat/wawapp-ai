import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/finance/models/wallet_models.dart';

/// Provider for all driver wallets
final driverWalletsProvider = StreamProvider<List<WalletModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('wallets')
      .where('type', isEqualTo: 'driver')
      .orderBy('balance', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => WalletModel.fromFirestore(doc))
          .toList());
});

/// Provider for platform wallet
final platformWalletProvider = StreamProvider<WalletModel?>((ref) {
  return FirebaseFirestore.instance
      .collection('wallets')
      .doc('platform_main')
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return WalletModel.fromFirestore(doc);
  });
});

/// Provider for a specific driver wallet
final driverWalletProvider =
    StreamProvider.family<WalletModel?, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('wallets')
      .doc(driverId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    return WalletModel.fromFirestore(doc);
  });
});

/// Provider for transactions for a specific wallet
final walletTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, walletId) {
  return FirebaseFirestore.instance
      .collection('transactions')
      .where('walletId', isEqualTo: walletId)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList());
});

/// Provider for all payouts
final payoutsProvider = StreamProvider<List<PayoutModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('payouts')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PayoutModel.fromFirestore(doc))
          .toList());
});

/// Provider for payouts by status
final payoutsByStatusProvider =
    StreamProvider.family<List<PayoutModel>, String>((ref, status) {
  return FirebaseFirestore.instance
      .collection('payouts')
      .where('status', isEqualTo: status)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PayoutModel.fromFirestore(doc))
          .toList());
});

/// Provider for payouts for a specific driver
final driverPayoutsProvider =
    StreamProvider.family<List<PayoutModel>, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('payouts')
      .where('driverId', isEqualTo: driverId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => PayoutModel.fromFirestore(doc))
          .toList());
});

/// Payout service for admin actions
class PayoutService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Create a new payout request
  Future<String> createPayoutRequest({
    required String driverId,
    required int amount,
    required String method,
    Map<String, dynamic>? recipientInfo,
    String? note,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminCreatePayoutRequest');
      final result = await callable.call<Map<String, dynamic>>({
        'driverId': driverId,
        'amount': amount,
        'method': method,
        if (recipientInfo != null) 'recipientInfo': recipientInfo,
        if (note != null) 'note': note,
      });

      return result.data['payoutId'] as String;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating payout request: $e');
      }
      rethrow;
    }
  }

  /// Update payout status
  Future<void> updatePayoutStatus({
    required String payoutId,
    required String newStatus,
    String? note,
  }) async {
    try {
      final callable = _functions.httpsCallable('adminUpdatePayoutStatus');
      await callable.call<Map<String, dynamic>>({
        'payoutId': payoutId,
        'newStatus': newStatus,
        if (note != null) 'note': note,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error updating payout status: $e');
      }
      rethrow;
    }
  }
}

/// Provider for payout service
final payoutServiceProvider = Provider<PayoutService>((ref) {
  return PayoutService();
});

class TopupRequestModel {
  final String id;
  final String driverId;
  final double amount;
  final String status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? adminId;
  final String? notes;

  const TopupRequestModel({
    required this.id,
    required this.driverId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.processedAt,
    this.adminId,
    this.notes,
  });

  factory TopupRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TopupRequestModel(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'pending',
      requestedAt:
          (data['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
      adminId: data['adminId'] as String?,
      notes: data['notes'] as String?,
    );
  }
}

final driverTopupRequestsProvider =
    StreamProvider<List<TopupRequestModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('topup_requests')
      .orderBy('requestedAt', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TopupRequestModel.fromFirestore(doc))
          .toList());
});

final pendingTopupRequestsProvider =
    StreamProvider<List<TopupRequestModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('topup_requests')
      .where('status', isEqualTo: 'pending')
      .orderBy('requestedAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => TopupRequestModel.fromFirestore(doc))
          .toList());
});
