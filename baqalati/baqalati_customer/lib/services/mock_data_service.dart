import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';

class MockDataService {
  // ============ STORES ============
  static List<StoreModel> getMockStores() {
    return [
      StoreModel(
        id: 'store_1',
        name: 'Épicerie Al-Baraka',
        nameAr: 'بقالة البركة',
        nameFr: 'Épicerie Al-Baraka',
        address: 'Tevragh Zeina, Nouakchott',
        addressAr: 'تفرغ زينة، نواكشوط',
        addressFr: 'Tevragh Zeina, Nouakchott',
        phone: '+222 22 33 44 55',
        imageUrl: 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=400',
        latitude: 18.0858,
        longitude: -15.9785,
        rating: 4.7,
        totalOrders: 342,
        isOpen: true,
        ownerId: 'merchant_1',
        categories: ['fruits', 'dairy', 'drinks', 'grains'],
        deliveryInfoAr: 'توصيل مجاني للطلبات فوق 500 أوقية',
        deliveryInfoFr: 'Livraison gratuite pour les commandes de plus de 500 MRU',
      ),
      StoreModel(
        id: 'store_2',
        name: 'Superette Sahel',
        nameAr: 'سوبيريت الساحل',
        nameFr: 'Superette Sahel',
        address: 'Ksar, Nouakchott',
        addressAr: 'لكصر، نواكشوط',
        addressFr: 'Ksar, Nouakchott',
        phone: '+222 33 44 55 66',
        imageUrl: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=400',
        latitude: 18.0735,
        longitude: -15.9582,
        rating: 4.3,
        totalOrders: 215,
        isOpen: true,
        ownerId: 'merchant_2',
        categories: ['meat', 'bakery', 'cleaning', 'canned'],
        deliveryInfoAr: 'توصيل خلال 30 دقيقة',
        deliveryInfoFr: 'Livraison en 30 minutes',
      ),
      StoreModel(
        id: 'store_3',
        name: 'Mini Market Chinguetti',
        nameAr: 'ميني ماركت شنقيط',
        nameFr: 'Mini Market Chinguetti',
        address: 'Arafat, Nouakchott',
        addressAr: 'عرفات، نواكشوط',
        addressFr: 'Arafat, Nouakchott',
        phone: '+222 44 55 66 77',
        imageUrl: 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400',
        latitude: 18.0500,
        longitude: -15.9400,
        rating: 4.1,
        totalOrders: 178,
        isOpen: true,
        ownerId: 'merchant_3',
        categories: ['fruits', 'drinks', 'snacks', 'personal'],
        deliveryInfoAr: 'رسوم التوصيل 50 أوقية',
        deliveryInfoFr: 'Frais de livraison 50 MRU',
      ),
      StoreModel(
        id: 'store_4',
        name: 'Épicerie Nouakchott Plus',
        nameAr: 'بقالة نواكشوط بلس',
        nameFr: 'Épicerie Nouakchott Plus',
        address: 'Sebkha, Nouakchott',
        addressAr: 'السبخة، نواكشوط',
        addressFr: 'Sebkha, Nouakchott',
        phone: '+222 55 66 77 88',
        imageUrl: 'https://images.unsplash.com/photo-1588964895597-cfccd6e2dbf9?w=400',
        latitude: 18.0650,
        longitude: -15.9700,
        rating: 4.5,
        totalOrders: 290,
        isOpen: false,
        ownerId: 'merchant_4',
        categories: ['grains', 'oils', 'spices', 'dairy'],
        deliveryInfoAr: 'مغلق حالياً - يفتح غداً الساعة 8 صباحاً',
        deliveryInfoFr: 'Fermé - Ouverture demain à 8h',
      ),
      StoreModel(
        id: 'store_5',
        name: 'Boutique El Waha',
        nameAr: 'بوتيك الواحة',
        nameFr: 'Boutique El Waha',
        address: 'Dar Naim, Nouakchott',
        addressAr: 'دار النعيم، نواكشوط',
        addressFr: 'Dar Naim, Nouakchott',
        phone: '+222 66 77 88 99',
        imageUrl: 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=400',
        latitude: 18.0900,
        longitude: -15.9300,
        rating: 4.6,
        totalOrders: 156,
        isOpen: true,
        ownerId: 'merchant_5',
        categories: ['fruits', 'meat', 'bakery', 'drinks'],
        deliveryInfoAr: 'توصيل مجاني لجميع الطلبات',
        deliveryInfoFr: 'Livraison gratuite pour toutes les commandes',
      ),
    ];
  }

  // ============ PRODUCTS ============
  static List<ProductModel> getMockProducts(String storeId) {
    final allProducts = <String, List<ProductModel>>{
      'store_1': [
        ProductModel(
          id: 'p1_1', storeId: 'store_1',
          name: 'Tomatoes', nameAr: 'طماطم', nameFr: 'Tomates',
          price: 30, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1546470427-0d4db154ceb8?w=300',
          category: 'fruits', categoryAr: 'فواكه وخضروات', categoryFr: 'Fruits et légumes',
        ),
        ProductModel(
          id: 'p1_2', storeId: 'store_1',
          name: 'Fresh Milk', nameAr: 'حليب طازج', nameFr: 'Lait frais',
          price: 45, unit: 'liter', unitAr: 'لتر', unitFr: 'litre',
          imageUrl: 'https://images.unsplash.com/photo-1563636619-e9143da7973b?w=300',
          category: 'dairy', categoryAr: 'ألبان وأجبان', categoryFr: 'Produits laitiers',
        ),
        ProductModel(
          id: 'p1_3', storeId: 'store_1',
          name: 'Rice', nameAr: 'أرز', nameFr: 'Riz',
          price: 80, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1586201375761-83865001e31c?w=300',
          category: 'grains', categoryAr: 'حبوب وبقوليات', categoryFr: 'Céréales et légumineuses',
        ),
        ProductModel(
          id: 'p1_4', storeId: 'store_1',
          name: 'Mineral Water', nameAr: 'ماء معدني', nameFr: 'Eau minérale',
          price: 15, unit: 'bottle', unitAr: 'قارورة', unitFr: 'bouteille',
          imageUrl: 'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=300',
          category: 'drinks', categoryAr: 'مشروبات', categoryFr: 'Boissons',
        ),
        ProductModel(
          id: 'p1_5', storeId: 'store_1',
          name: 'Onions', nameAr: 'بصل', nameFr: 'Oignons',
          price: 25, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?w=300',
          category: 'fruits', categoryAr: 'فواكه وخضروات', categoryFr: 'Fruits et légumes',
        ),
        ProductModel(
          id: 'p1_6', storeId: 'store_1',
          name: 'Sugar', nameAr: 'سكر', nameFr: 'Sucre',
          price: 50, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1558642452-9d2a7deb7f62?w=300',
          category: 'grains', categoryAr: 'حبوب وبقوليات', categoryFr: 'Céréales et légumineuses',
        ),
        ProductModel(
          id: 'p1_7', storeId: 'store_1',
          name: 'Cooking Oil', nameAr: 'زيت طبخ', nameFr: 'Huile de cuisine',
          price: 120, unit: 'liter', unitAr: 'لتر', unitFr: 'litre',
          imageUrl: 'https://images.unsplash.com/photo-1474979266404-7eaacdc948b6?w=300',
          category: 'oils', categoryAr: 'زيوت وسمن', categoryFr: 'Huiles et beurre',
        ),
        ProductModel(
          id: 'p1_8', storeId: 'store_1',
          name: 'Green Tea', nameAr: 'شاي أخضر', nameFr: 'Thé vert',
          price: 200, unit: 'box', unitAr: 'علبة', unitFr: 'boîte',
          imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=300',
          category: 'drinks', categoryAr: 'مشروبات', categoryFr: 'Boissons',
          descriptionAr: 'شاي أخضر صيني ممتاز - الشاي الموريتاني الأصيل',
          descriptionFr: 'Thé vert chinois de qualité supérieure - Le thé mauritanien authentique',
        ),
      ],
      'store_2': [
        ProductModel(
          id: 'p2_1', storeId: 'store_2',
          name: 'Chicken', nameAr: 'دجاج', nameFr: 'Poulet',
          price: 180, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1587593810167-a84920ea0781?w=300',
          category: 'meat', categoryAr: 'لحوم ودواجن', categoryFr: 'Viandes et volailles',
        ),
        ProductModel(
          id: 'p2_2', storeId: 'store_2',
          name: 'Bread', nameAr: 'خبز', nameFr: 'Pain',
          price: 10, unit: 'piece', unitAr: 'قطعة', unitFr: 'pièce',
          imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=300',
          category: 'bakery', categoryAr: 'مخبوزات', categoryFr: 'Boulangerie',
        ),
        ProductModel(
          id: 'p2_3', storeId: 'store_2',
          name: 'Dish Soap', nameAr: 'صابون أطباق', nameFr: 'Liquide vaisselle',
          price: 35, unit: 'bottle', unitAr: 'قارورة', unitFr: 'bouteille',
          imageUrl: 'https://images.unsplash.com/photo-1583947215259-38e31be8751f?w=300',
          category: 'cleaning', categoryAr: 'مواد تنظيف', categoryFr: 'Produits ménagers',
        ),
        ProductModel(
          id: 'p2_4', storeId: 'store_2',
          name: 'Canned Tuna', nameAr: 'تونة معلبة', nameFr: 'Thon en conserve',
          price: 60, unit: 'can', unitAr: 'علبة', unitFr: 'boîte',
          imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=300',
          category: 'canned', categoryAr: 'معلبات', categoryFr: 'Conserves',
        ),
        ProductModel(
          id: 'p2_5', storeId: 'store_2',
          name: 'Lamb Meat', nameAr: 'لحم غنم', nameFr: 'Viande d\'agneau',
          price: 350, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1603048297172-c92544798d5a?w=300',
          category: 'meat', categoryAr: 'لحوم ودواجن', categoryFr: 'Viandes et volailles',
        ),
        ProductModel(
          id: 'p2_6', storeId: 'store_2',
          name: 'Laundry Detergent', nameAr: 'مسحوق غسيل', nameFr: 'Lessive',
          price: 90, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1582735689369-4fe89db7114c?w=300',
          category: 'cleaning', categoryAr: 'مواد تنظيف', categoryFr: 'Produits ménagers',
        ),
      ],
      'store_3': [
        ProductModel(
          id: 'p3_1', storeId: 'store_3',
          name: 'Bananas', nameAr: 'موز', nameFr: 'Bananes',
          price: 40, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?w=300',
          category: 'fruits', categoryAr: 'فواكه وخضروات', categoryFr: 'Fruits et légumes',
        ),
        ProductModel(
          id: 'p3_2', storeId: 'store_3',
          name: 'Coca Cola', nameAr: 'كوكا كولا', nameFr: 'Coca Cola',
          price: 20, unit: 'can', unitAr: 'علبة', unitFr: 'canette',
          imageUrl: 'https://images.unsplash.com/photo-1554866585-cd94860890b7?w=300',
          category: 'drinks', categoryAr: 'مشروبات', categoryFr: 'Boissons',
        ),
        ProductModel(
          id: 'p3_3', storeId: 'store_3',
          name: 'Chips', nameAr: 'شيبس', nameFr: 'Chips',
          price: 25, unit: 'pack', unitAr: 'كيس', unitFr: 'paquet',
          imageUrl: 'https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300',
          category: 'snacks', categoryAr: 'وجبات خفيفة', categoryFr: 'Snacks',
        ),
        ProductModel(
          id: 'p3_4', storeId: 'store_3',
          name: 'Shampoo', nameAr: 'شامبو', nameFr: 'Shampooing',
          price: 55, unit: 'bottle', unitAr: 'قارورة', unitFr: 'bouteille',
          imageUrl: 'https://images.unsplash.com/photo-1615397349754-cfa2066a298e?w=300',
          category: 'personal', categoryAr: 'عناية شخصية', categoryFr: 'Soins personnels',
        ),
        ProductModel(
          id: 'p3_5', storeId: 'store_3',
          name: 'Oranges', nameAr: 'برتقال', nameFr: 'Oranges',
          price: 35, unit: 'kg', unitAr: 'كغ', unitFr: 'kg',
          imageUrl: 'https://images.unsplash.com/photo-1547514701-42782101795e?w=300',
          category: 'fruits', categoryAr: 'فواكه وخضروات', categoryFr: 'Fruits et légumes',
        ),
      ],
    };

    return allProducts[storeId] ?? allProducts['store_1']!;
  }

  // ============ MOCK ORDERS ============
  static List<OrderModel> getMockOrders() {
    return [
      OrderModel(
        id: 'ORD-001',
        userId: 'user_1',
        userName: 'محمد أحمد',
        userPhone: '+222 22 11 33 44',
        storeId: 'store_1',
        storeName: 'بقالة البركة',
        items: [
          CartItem(
            productId: 'p1_1', productName: 'Tomatoes',
            productNameAr: 'طماطم', productNameFr: 'Tomates',
            price: 30, quantity: 2, unit: 'كغ',
          ),
          CartItem(
            productId: 'p1_3', productName: 'Rice',
            productNameAr: 'أرز', productNameFr: 'Riz',
            price: 80, quantity: 1, unit: 'كغ',
          ),
          CartItem(
            productId: 'p1_8', productName: 'Green Tea',
            productNameAr: 'شاي أخضر', productNameFr: 'Thé vert',
            price: 200, quantity: 1, unit: 'علبة',
          ),
        ],
        totalAmount: 340,
        status: OrderStatus.preparing,
        deliveryType: DeliveryType.delivery,
        deliveryAddress: 'تفرغ زينة، شارع جمال عبد الناصر',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      OrderModel(
        id: 'ORD-002',
        userId: 'user_1',
        userName: 'محمد أحمد',
        userPhone: '+222 22 11 33 44',
        storeId: 'store_2',
        storeName: 'سوبيريت الساحل',
        items: [
          CartItem(
            productId: 'p2_1', productName: 'Chicken',
            productNameAr: 'دجاج', productNameFr: 'Poulet',
            price: 180, quantity: 2, unit: 'كغ',
          ),
          CartItem(
            productId: 'p2_2', productName: 'Bread',
            productNameAr: 'خبز', productNameFr: 'Pain',
            price: 10, quantity: 5, unit: 'قطعة',
          ),
        ],
        totalAmount: 410,
        status: OrderStatus.pending,
        deliveryType: DeliveryType.pickup,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      OrderModel(
        id: 'ORD-003',
        userId: 'user_1',
        userName: 'محمد أحمد',
        userPhone: '+222 22 11 33 44',
        storeId: 'store_1',
        storeName: 'بقالة البركة',
        items: [
          CartItem(
            productId: 'p1_7', productName: 'Cooking Oil',
            productNameAr: 'زيت طبخ', productNameFr: 'Huile de cuisine',
            price: 120, quantity: 1, unit: 'لتر',
          ),
          CartItem(
            productId: 'p1_6', productName: 'Sugar',
            productNameAr: 'سكر', productNameFr: 'Sucre',
            price: 50, quantity: 2, unit: 'كغ',
          ),
        ],
        totalAmount: 220,
        status: OrderStatus.delivered,
        deliveryType: DeliveryType.delivery,
        deliveryAddress: 'لكصر، بالقرب من المسجد الكبير',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  // ============ MOCK USER ============
  static UserModel getMockCustomer() {
    return UserModel(
      id: 'user_1',
      name: 'محمد أحمد',
      email: 'mohammed@example.com',
      phone: '+222 22 11 33 44',
      address: 'تفرغ زينة، نواكشوط',
      role: UserRole.customer,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );
  }

  static UserModel getMockMerchant() {
    return UserModel(
      id: 'merchant_1',
      name: 'أحمد ولد محمد',
      email: 'merchant@example.com',
      phone: '+222 22 33 44 55',
      address: 'تفرغ زينة، نواكشوط',
      role: UserRole.merchant,
      storeId: 'store_1',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );
  }

  // ============ CATEGORIES ============
  static List<Map<String, String>> getCategories() {
    return [
      {'id': 'fruits', 'ar': 'فواكه وخضروات', 'fr': 'Fruits et légumes', 'icon': '🥬'},
      {'id': 'dairy', 'ar': 'ألبان وأجبان', 'fr': 'Produits laitiers', 'icon': '🥛'},
      {'id': 'meat', 'ar': 'لحوم ودواجن', 'fr': 'Viandes et volailles', 'icon': '🥩'},
      {'id': 'bakery', 'ar': 'مخبوزات', 'fr': 'Boulangerie', 'icon': '🍞'},
      {'id': 'drinks', 'ar': 'مشروبات', 'fr': 'Boissons', 'icon': '🥤'},
      {'id': 'snacks', 'ar': 'وجبات خفيفة', 'fr': 'Snacks', 'icon': '🍿'},
      {'id': 'cleaning', 'ar': 'مواد تنظيف', 'fr': 'Produits ménagers', 'icon': '🧹'},
      {'id': 'personal', 'ar': 'عناية شخصية', 'fr': 'Soins personnels', 'icon': '🧴'},
      {'id': 'grains', 'ar': 'حبوب وبقوليات', 'fr': 'Céréales', 'icon': '🌾'},
      {'id': 'oils', 'ar': 'زيوت وسمن', 'fr': 'Huiles', 'icon': '🫒'},
      {'id': 'spices', 'ar': 'بهارات وتوابل', 'fr': 'Épices', 'icon': '🌶️'},
      {'id': 'canned', 'ar': 'معلبات', 'fr': 'Conserves', 'icon': '🥫'},
    ];
  }
}
