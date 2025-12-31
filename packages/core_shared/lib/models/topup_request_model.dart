import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a top-up request
enum TopupRequestStatus {
  pending,
  approved,
  rejected,
}

/// Model for driver wallet top-up requests
class TopupRequestModel {
  final String id;
  final String userId;
  final String bankAppId;
  final String bankAppName;
  final String destinationCode;
  final int amount;
  final String? senderPhone;
  final TopupRequestStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? rejectionReason;

  TopupRequestModel({
    required this.id,
    required this.userId,
    required this.bankAppId,
    required this.bankAppName,
    required this.destinationCode,
    required this.amount,
    this.senderPhone,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.processedBy,
    this.rejectionReason,
  });

  /// Create from Firestore document
  factory TopupRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TopupRequestModel(
      id: doc.id,
      userId: data['userId'] as String,
      bankAppId: data['bankAppId'] as String,
      bankAppName: data['bankAppName'] as String,
      destinationCode: data['destinationCode'] as String,
      amount: data['amount'] as int,
      senderPhone: data['senderPhone'] as String?,
      status: TopupRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TopupRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: data['processedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String?,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bankAppId': bankAppId,
      'bankAppName': bankAppName,
      'destinationCode': destinationCode,
      'amount': amount,
      'senderPhone': senderPhone,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'rejectionReason': rejectionReason,
    };
  }

  /// Create a copy with updated fields
  TopupRequestModel copyWith({
    String? id,
    String? userId,
    String? bankAppId,
    String? bankAppName,
    String? destinationCode,
    int? amount,
    String? senderPhone,
    TopupRequestStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? processedBy,
    String? rejectionReason,
  }) {
    return TopupRequestModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bankAppId: bankAppId ?? this.bankAppId,
      bankAppName: bankAppName ?? this.bankAppName,
      destinationCode: destinationCode ?? this.destinationCode,
      amount: amount ?? this.amount,
      senderPhone: senderPhone ?? this.senderPhone,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
