import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_shared/core_shared.dart';

/// Service for managing wallet top-up requests
class TopupService {
  final FirebaseFirestore _firestore;

  TopupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get bank apps configuration
  Future<List<BankAppConfig>> getBankApps() async {
    final doc = await _firestore.collection('app_config').doc('topup_config').get();

    if (!doc.exists) {
      return [];
    }

    final data = doc.data();
    final bankApps = data?['bankApps'] as List<dynamic>? ?? [];

    return bankApps
        .map((app) => BankAppConfig.fromMap(app as Map<String, dynamic>))
        .where((app) => app.isActive)
        .toList();
  }

  /// Create a new top-up request
  Future<String> createTopupRequest({
    required String userId,
    required String bankAppId,
    required String bankAppName,
    required String destinationCode,
    required int amount,
    String? senderPhone,
  }) async {
    final request = TopupRequestModel(
      id: '',
      userId: userId,
      bankAppId: bankAppId,
      bankAppName: bankAppName,
      destinationCode: destinationCode,
      amount: amount,
      senderPhone: senderPhone,
      status: TopupRequestStatus.pending,
      createdAt: DateTime.now(),
    );

    final docRef = await _firestore.collection('topup_requests').add(request.toFirestore());
    return docRef.id;
  }

  /// Get top-up requests stream for a user
  Stream<List<TopupRequestModel>> getTopupRequestsStream(String userId) {
    return _firestore
        .collection('topup_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TopupRequestModel.fromFirestore(doc))
            .toList());
  }

  /// Get pending requests count
  Stream<int> getPendingCountStream(String userId) {
    return _firestore
        .collection('topup_requests')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
