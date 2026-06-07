import 'package:equatable/equatable.dart';

/// Predefined laundry item types with Arabic and French names.
enum LaundryItemType {
  shirt('قميص', 'Chemise'),
  pants('بنطلون', 'Pantalon'),
  thobe('ثوب', 'Thobe'),
  dress('فستان', 'Robe'),
  jacket('جاكيت', 'Veste'),
  blanket('بطانية', 'Couverture'),
  bedsheet('ملاءة', 'Drap'),
  towel('منشفة', 'Serviette'),
  curtain('ستارة', 'Rideau'),
  abaya('عباية', 'Abaya'),
  melhfa('ملحفة', 'Melhfa'),
  boubou('دراعة', 'Boubou'),
  underwear('ملابس داخلية', 'Sous-vêtements'),
  socks('جوارب', 'Chaussettes'),
  other('أخرى', 'Autre');

  final String arabicName;
  final String frenchName;

  const LaundryItemType(this.arabicName, this.frenchName);

  String getLocalizedName(String locale) {
    return locale == 'ar' ? arabicName : frenchName;
  }
}

/// Represents a single item in a laundry order.
class OrderItemModel extends Equatable {
  final String id;
  final LaundryItemType type;
  final String? customName;
  final int quantity;
  final double pricePerItem;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.type,
    this.customName,
    required this.quantity,
    required this.pricePerItem,
    this.notes,
  });

  /// Total price for this item line.
  double get totalPrice => quantity * pricePerItem;

  /// Creates an OrderItemModel from a Map.
  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      id: map['id'] ?? '',
      type: LaundryItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => LaundryItemType.other,
      ),
      customName: map['customName'],
      quantity: map['quantity'] ?? 1,
      pricePerItem: (map['pricePerItem'] ?? 0).toDouble(),
      notes: map['notes'],
    );
  }

  /// Converts the OrderItemModel to a Map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'customName': customName,
      'quantity': quantity,
      'pricePerItem': pricePerItem,
      'notes': notes,
    };
  }

  OrderItemModel copyWith({
    String? id,
    LaundryItemType? type,
    String? customName,
    int? quantity,
    double? pricePerItem,
    String? notes,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      type: type ?? this.type,
      customName: customName ?? this.customName,
      quantity: quantity ?? this.quantity,
      pricePerItem: pricePerItem ?? this.pricePerItem,
      notes: notes ?? this.notes,
    );
  }

  @override
  List<Object?> get props => [id, type, customName, quantity, pricePerItem, notes];
}
