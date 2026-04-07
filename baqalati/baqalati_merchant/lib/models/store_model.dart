class StoreModel {
  final String id;
  final String name;
  final String nameAr;
  final String nameFr;
  final String address;
  final String addressAr;
  final String addressFr;
  final String phone;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final double rating;
  final int totalOrders;
  final bool isOpen;
  final String ownerId;
  final List<String> categories;
  final String deliveryInfo;
  final String deliveryInfoAr;
  final String deliveryInfoFr;

  StoreModel({
    required this.id,
    required this.name,
    this.nameAr = '',
    this.nameFr = '',
    required this.address,
    this.addressAr = '',
    this.addressFr = '',
    required this.phone,
    required this.imageUrl,
    this.latitude = 18.0735,
    this.longitude = -15.9582,
    this.rating = 4.5,
    this.totalOrders = 0,
    this.isOpen = true,
    required this.ownerId,
    this.categories = const [],
    this.deliveryInfo = '',
    this.deliveryInfoAr = '',
    this.deliveryInfoFr = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameAr': nameAr,
      'nameFr': nameFr,
      'address': address,
      'addressAr': addressAr,
      'addressFr': addressFr,
      'phone': phone,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'totalOrders': totalOrders,
      'isOpen': isOpen,
      'ownerId': ownerId,
      'categories': categories,
      'deliveryInfo': deliveryInfo,
      'deliveryInfoAr': deliveryInfoAr,
      'deliveryInfoFr': deliveryInfoFr,
    };
  }

  factory StoreModel.fromMap(Map<String, dynamic> map) {
    return StoreModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameFr: map['nameFr'] ?? '',
      address: map['address'] ?? '',
      addressAr: map['addressAr'] ?? '',
      addressFr: map['addressFr'] ?? '',
      phone: map['phone'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] ?? 18.0735).toDouble(),
      longitude: (map['longitude'] ?? -15.9582).toDouble(),
      rating: (map['rating'] ?? 4.5).toDouble(),
      totalOrders: map['totalOrders'] ?? 0,
      isOpen: map['isOpen'] ?? true,
      ownerId: map['ownerId'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      deliveryInfo: map['deliveryInfo'] ?? '',
      deliveryInfoAr: map['deliveryInfoAr'] ?? '',
      deliveryInfoFr: map['deliveryInfoFr'] ?? '',
    );
  }

  String getLocalizedName(String locale) {
    if (locale == 'ar') return nameAr.isNotEmpty ? nameAr : name;
    if (locale == 'fr') return nameFr.isNotEmpty ? nameFr : name;
    return name;
  }

  String getLocalizedAddress(String locale) {
    if (locale == 'ar') return addressAr.isNotEmpty ? addressAr : address;
    if (locale == 'fr') return addressFr.isNotEmpty ? addressFr : address;
    return address;
  }
}
