import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a customer rating for a completed order.
class RatingModel extends Equatable {
  final String id;
  final String orderId;
  final String customerId;
  final String laundryId;
  final int rating; // 1-5 stars
  final String? comment;
  final DateTime createdAt;

  const RatingModel({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.laundryId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory RatingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RatingModel(
      id: doc.id,
      orderId: data['orderId'] ?? '',
      customerId: data['customerId'] ?? '',
      laundryId: data['laundryId'] ?? '',
      rating: data['rating'] ?? 0,
      comment: data['comment'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'laundryId': laundryId,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  @override
  List<Object?> get props => [id, orderId, customerId, laundryId, rating, comment, createdAt];
}
