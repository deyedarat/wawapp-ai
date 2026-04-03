import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wallet data model
class WalletData {
  final double totalBalance;
  final double todayEarnings;
  final double weekEarnings;

  const WalletData({
    required this.totalBalance,
    required this.todayEarnings,
    required this.weekEarnings,
  });

  factory WalletData.empty() {
    return const WalletData(
      totalBalance: 0,
      todayEarnings: 0,
      weekEarnings: 0,
    );
  }
}

/// Provider for driver wallet data
final walletDataProvider = StreamProvider.family<WalletData, String>((ref, driverId) {
  final firestore = FirebaseFirestore.instance;
  
  return firestore
      .collection('wallets')
      .doc(driverId)
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) {
      return WalletData.empty();
    }

    final data = snapshot.data()!;
    return WalletData(
      totalBalance: (data['balance'] as num?)?.toDouble() ?? 0,
      todayEarnings: (data['todayEarnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (data['weekEarnings'] as num?)?.toDouble() ?? 0,
    );
  });
});

/// Daily summary model
class DailySummary {
  final int tripsCount;
  final double earnings;

  const DailySummary({
    required this.tripsCount,
    required this.earnings,
  });

  factory DailySummary.empty() {
    return const DailySummary(
      tripsCount: 0,
      earnings: 0,
    );
  }
}

/// Provider for daily summary (for home screen)
/// Uses existing index: driverId ASC, status ASC, completedAt DESC
final dailySummaryProvider = StreamProvider.family<DailySummary, String>((ref, driverId) {
  final firestore = FirebaseFirestore.instance;
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  
  return firestore
      .collection('orders')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'completed')
      .orderBy('completedAt', descending: true)
      .snapshots()
      .map((snapshot) {
    // Filter today's orders locally to match existing index
    double totalEarnings = 0;
    int count = 0;
    for (final doc in snapshot.docs) {
      final ts = doc.data()['completedAt'] as Timestamp?;
      if (ts == null) continue;
      final completedAt = ts.toDate();
      if (completedAt.isBefore(startOfDay)) break; // Sorted DESC, so stop early
      final price = (doc.data()['price'] as num?)?.toDouble() ?? 0;
      totalEarnings += price;
      count++;
    }

    return DailySummary(tripsCount: count, earnings: totalEarnings);
  });
});

class WalletTransaction {
  final String id;
  final String type;
  final String source;
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.source,
    required this.amount,
    required this.balanceAfter,
    this.note,
    required this.createdAt,
  });

  factory WalletTransaction.fromFirestore(Map<String, dynamic> data, String id) {
    return WalletTransaction(
      id: id,
      type: data['type'] as String? ?? 'credit',
      source: data['source'] as String? ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      balanceAfter: (data['balanceAfter'] as num?)?.toDouble() ?? 0,
      note: data['note'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

final driverTransactionsProvider =
    StreamProvider.family<List<WalletTransaction>, String>((ref, driverId) {
  return FirebaseFirestore.instance
      .collection('transactions')
      .where('walletId', isEqualTo: driverId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => WalletTransaction.fromFirestore(doc.data(), doc.id))
          .toList());
});
