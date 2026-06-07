import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'order_item_model.dart';

/// Represents the status of a laundry order.
enum OrderStatus {
  received('تم الاستلام', 'Reçue'),
  washing('قيد الغسيل', 'En lavage'),
  ready('جاهزة', 'Prête'),
  delivered('تم التسليم', 'Livrée'),
  cancelled('ملغاة', 'Annulée');

  final String arabicName;
  final String frenchName;

  const OrderStatus(this.arabicName, this.frenchName);

  String getLocalizedName(String locale) {
    return locale == 'ar' ? arabicName : frenchName;
  }
}

/// Represents a laundry order.
class OrderModel extends Equatable {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String laundryId;
  final List<OrderItemModel> items;
  final OrderStatus status;
  final double totalPrice;
  final double? discount;
  final DateTime createdAt;
  final DateTime estimatedCompletionTime;
  final DateTime? completedAt;
  final DateTime? deliveredAt;
  final String? notes;
  final int? rating;
  final String? ratingComment;
  final String createdByStaffId;

  const OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.laundryId,
    required this.items,
    required this.status,
    required this.totalPrice,
    this.discount,
    required this.createdAt,
    required this.estimatedCompletionTime,
    this.completedAt,
    this.deliveredAt,
    this.notes,
    this.rating,
    this.ratingComment,
    required this.createdByStaffId,
  });

  /// Total number of items in the order.
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  /// Final price after discount.
  double get finalPrice => totalPrice - (discount ?? 0);

  /// Whether the order is still active (not delivered or cancelled).
  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  /// Creates an OrderModel from a Firestore document snapshot.
  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      laundryId: data['laundryId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => OrderItemModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      status: OrderStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => OrderStatus.received,
      ),
      totalPrice: (data['totalPrice'] ?? 0).toDouble(),
      discount: data['discount']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedCompletionTime:
          (data['estimatedCompletionTime'] as Timestamp?)?.toDate() ??
              DateTime.now().add(const Duration(hours: 24)),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      rating: data['rating'],
      ratingComment: data['ratingComment'],
      createdByStaffId: data['createdByStaffId'] ?? '',
    );
  }

  /// Converts the OrderModel to a Map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'laundryId': laundryId,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status.name,
      'totalPrice': totalPrice,
      'discount': discount,
      'createdAt': Timestamp.fromDate(createdAt),
      'estimatedCompletionTime': Timestamp.fromDate(estimatedCompletionTime),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'notes': notes,
      'rating': rating,
      'ratingComment': ratingComment,
      'createdByStaffId': createdByStaffId,
    };
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? laundryId,
    List<OrderItemModel>? items,
    OrderStatus? status,
    double? totalPrice,
    double? discount,
    DateTime? createdAt,
    DateTime? estimatedCompletionTime,
    DateTime? completedAt,
    DateTime? deliveredAt,
    String? notes,
    int? rating,
    String? ratingComment,
    String? createdByStaffId,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      laundryId: laundryId ?? this.laundryId,
      items: items ?? this.items,
      status: status ?? this.status,
      totalPrice: totalPrice ?? this.totalPrice,
      discount: discount ?? this.discount,
      createdAt: createdAt ?? this.createdAt,
      estimatedCompletionTime: estimatedCompletionTime ?? this.estimatedCompletionTime,
      completedAt: completedAt ?? this.completedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      notes: notes ?? this.notes,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      createdByStaffId: createdByStaffId ?? this.createdByStaffId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        laundryId,
        items,
        status,
        totalPrice,
        discount,
        createdAt,
        estimatedCompletionTime,
        completedAt,
        deliveredAt,
        notes,
        rating,
        ratingComment,
        createdByStaffId,
      ];
}
