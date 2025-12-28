import 'package:cloud_firestore/cloud_firestore.dart';

/// Wallet model representing driver or platform wallet
class WalletModel {
  final String id;
  final String type; // 'driver' or 'platform'
  final String? ownerId;
  final int balance;
  final int totalCredited;
  final int totalDebited;
  final int pendingPayout;
  final String currency;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WalletModel({
    required this.id,
    required this.type,
    this.ownerId,
    required this.balance,
    required this.totalCredited,
    required this.totalDebited,
    required this.pendingPayout,
    required this.currency,
    this.createdAt,
    this.updatedAt,
  });

  factory WalletModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WalletModel(
      id: doc.id,
      type: data['type'] as String? ?? 'driver',
      ownerId: data['ownerId'] as String?,
      balance: data['balance'] as int? ?? 0,
      totalCredited: data['totalCredited'] as int? ?? 0,
      totalDebited: data['totalDebited'] as int? ?? 0,
      pendingPayout: data['pendingPayout'] as int? ?? 0,
      currency: data['currency'] as String? ?? 'MRU',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  int get availableBalance => balance - pendingPayout;
}

/// Transaction (ledger entry) model
class TransactionModel {
  final String id;
  final String walletId;
  final String type; // 'credit' or 'debit'
  final String source; // 'order_settlement', 'payout', etc.
  final int amount;
  final String currency;
  final String? orderId;
  final String? payoutId;
  final String? adminId;
  final int? balanceBefore;
  final int? balanceAfter;
  final String? note;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;

  TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.source,
    required this.amount,
    required this.currency,
    this.orderId,
    this.payoutId,
    this.adminId,
    this.balanceBefore,
    this.balanceAfter,
    this.note,
    this.metadata,
    this.createdAt,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      walletId: data['walletId'] as String? ?? '',
      type: data['type'] as String? ?? 'credit',
      source: data['source'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      currency: data['currency'] as String? ?? 'MRU',
      orderId: data['orderId'] as String?,
      payoutId: data['payoutId'] as String?,
      adminId: data['adminId'] as String?,
      balanceBefore: data['balanceBefore'] as int?,
      balanceAfter: data['balanceAfter'] as int?,
      note: data['note'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Payout model
class PayoutModel {
  final String id;
  final String driverId;
  final String walletId;
  final int amount;
  final String currency;
  final String method; // 'manual', 'bank_transfer', etc.
  final String status; // 'requested', 'approved', 'processing', 'completed', 'rejected'
  final String requestedByAdminId;
  final String? processedByAdminId;
  final String? transactionId;
  final Map<String, dynamic>? recipientInfo;
  final String? note;
  final String? rejectionReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  PayoutModel({
    required this.id,
    required this.driverId,
    required this.walletId,
    required this.amount,
    required this.currency,
    required this.method,
    required this.status,
    required this.requestedByAdminId,
    this.processedByAdminId,
    this.transactionId,
    this.recipientInfo,
    this.note,
    this.rejectionReason,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory PayoutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PayoutModel(
      id: doc.id,
      driverId: data['driverId'] as String? ?? '',
      walletId: data['walletId'] as String? ?? '',
      amount: data['amount'] as int? ?? 0,
      currency: data['currency'] as String? ?? 'MRU',
      method: data['method'] as String? ?? 'manual',
      status: data['status'] as String? ?? 'requested',
      requestedByAdminId: data['requestedByAdminId'] as String? ?? '',
      processedByAdminId: data['processedByAdminId'] as String?,
      transactionId: data['transactionId'] as String?,
      recipientInfo: data['recipientInfo'] as Map<String, dynamic>?,
      note: data['note'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}
