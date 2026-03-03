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
      .collection('drivers')
      .doc(driverId)
      .collection('wallet')
      .doc('summary')
      .snapshots()
      .map((snapshot) {
    if (!snapshot.exists) {
      return WalletData.empty();
    }

    final data = snapshot.data()!;
    return WalletData(
      totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0,
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
final dailySummaryProvider = StreamProvider.family<DailySummary, String>((ref, driverId) {
  final firestore = FirebaseFirestore.instance;
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);
  
  return firestore
      .collection('orders')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'completed')
      .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) {
      return DailySummary.empty();
    }

    double totalEarnings = 0;
    for (final doc in snapshot.docs) {
      final price = (doc.data()['price'] as num?)?.toDouble() ?? 0;
      totalEarnings += price;
    }

    return DailySummary(
      tripsCount: snapshot.docs.length,
      earnings: totalEarnings,
    );
  });
});
