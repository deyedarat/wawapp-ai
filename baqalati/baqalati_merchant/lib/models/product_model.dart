class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String nameAr;
  final String nameFr;
  final String description;
  final String descriptionAr;
  final String descriptionFr;
  final double price;
  final String unit;
  final String unitAr;
  final String unitFr;
  final String imageUrl;
  final String category;
  final String categoryAr;
  final String categoryFr;
  final bool isAvailable;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.nameAr = '',
    this.nameFr = '',
    this.description = '',
    this.descriptionAr = '',
    this.descriptionFr = '',
    required this.price,
    this.unit = 'kg',
    this.unitAr = 'كغ',
    this.unitFr = 'kg',
    required this.imageUrl,
    this.category = '',
    this.categoryAr = '',
    this.categoryFr = '',
    this.isAvailable = true,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'nameAr': nameAr,
      'nameFr': nameFr,
      'description': description,
      'descriptionAr': descriptionAr,
      'descriptionFr': descriptionFr,
      'price': price,
      'unit': unit,
      'unitAr': unitAr,
      'unitFr': unitFr,
      'imageUrl': imageUrl,
      'category': category,
      'categoryAr': categoryAr,
      'categoryFr': categoryFr,
      'isAvailable': isAvailable,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameFr: map['nameFr'] ?? '',
      description: map['description'] ?? '',
      descriptionAr: map['descriptionAr'] ?? '',
      descriptionFr: map['descriptionFr'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'kg',
      unitAr: map['unitAr'] ?? 'كغ',
      unitFr: map['unitFr'] ?? 'kg',
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      categoryAr: map['categoryAr'] ?? '',
      categoryFr: map['categoryFr'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : null,
    );
  }

  String getLocalizedName(String locale) {
    if (locale == 'ar') return nameAr.isNotEmpty ? nameAr : name;
    if (locale == 'fr') return nameFr.isNotEmpty ? nameFr : name;
    return name;
  }

  String getLocalizedUnit(String locale) {
    if (locale == 'ar') return unitAr.isNotEmpty ? unitAr : unit;
    if (locale == 'fr') return unitFr.isNotEmpty ? unitFr : unit;
    return unit;
  }

  String getLocalizedCategory(String locale) {
    if (locale == 'ar') return categoryAr.isNotEmpty ? categoryAr : category;
    if (locale == 'fr') return categoryFr.isNotEmpty ? categoryFr : category;
    return category;
  }

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? nameAr,
    String? nameFr,
    String? description,
    String? descriptionAr,
    String? descriptionFr,
    double? price,
    String? unit,
    String? unitAr,
    String? unitFr,
    String? imageUrl,
    String? category,
    String? categoryAr,
    String? categoryFr,
    bool? isAvailable,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      nameAr: nameAr ?? this.nameAr,
      nameFr: nameFr ?? this.nameFr,
      description: description ?? this.description,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      descriptionFr: descriptionFr ?? this.descriptionFr,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      unitAr: unitAr ?? this.unitAr,
      unitFr: unitFr ?? this.unitFr,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      categoryAr: categoryAr ?? this.categoryAr,
      categoryFr: categoryFr ?? this.categoryFr,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
