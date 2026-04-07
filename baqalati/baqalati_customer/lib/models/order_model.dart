enum OrderStatus {
  pending,    // جديد
  preparing,  // قيد التجهيز
  ready,      // جاهز
  delivered,  // تم التسليم
  cancelled,  // ملغي
}

enum DeliveryType {
  delivery,   // توصيل
  pickup,     // استلام
}

class CartItem {
  final String productId;
  final String productName;
  final String productNameAr;
  final String productNameFr;
  final double price;
  final String unit;
  int quantity;
  final String imageUrl;

  CartItem({
    required this.productId,
    required this.productName,
    this.productNameAr = '',
    this.productNameFr = '',
    required this.price,
    this.unit = '',
    this.quantity = 1,
    this.imageUrl = '',
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productNameAr': productNameAr,
      'productNameFr': productNameFr,
      'price': price,
      'unit': unit,
      'quantity': quantity,
      'imageUrl': imageUrl,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      productNameAr: map['productNameAr'] ?? '',
      productNameFr: map['productNameFr'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      quantity: map['quantity'] ?? 1,
      imageUrl: map['imageUrl'] ?? '',
    );
  }

  String getLocalizedName(String locale) {
    if (locale == 'ar') return productNameAr.isNotEmpty ? productNameAr : productName;
    if (locale == 'fr') return productNameFr.isNotEmpty ? productNameFr : productName;
    return productName;
  }
}

class OrderModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhone;
  final String storeId;
  final String storeName;
  final List<CartItem> items;
  final double totalAmount;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final String deliveryAddress;
  final String notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhone = '',
    required this.storeId,
    required this.storeName,
    required this.items,
    required this.totalAmount,
    this.status = OrderStatus.pending,
    this.deliveryType = DeliveryType.delivery,
    this.deliveryAddress = '',
    this.notes = '',
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'storeId': storeId,
      'storeName': storeName,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': totalAmount,
      'status': status.name,
      'deliveryType': deliveryType.name,
      'deliveryAddress': deliveryAddress,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userPhone: map['userPhone'] ?? '',
      storeId: map['storeId'] ?? '',
      storeName: map['storeName'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => CartItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => OrderStatus.pending,
      ),
      deliveryType: DeliveryType.values.firstWhere(
        (e) => e.name == map['deliveryType'],
        orElse: () => DeliveryType.delivery,
      ),
      deliveryAddress: map['deliveryAddress'] ?? '',
      notes: map['notes'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : null,
    );
  }

  OrderModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhone,
    String? storeId,
    String? storeName,
    List<CartItem>? items,
    double? totalAmount,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? deliveryAddress,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
