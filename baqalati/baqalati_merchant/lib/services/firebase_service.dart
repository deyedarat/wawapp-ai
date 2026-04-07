/// Firebase Service Layer for Baqalati
///
/// This file provides the Firebase integration layer.
/// Currently uses mock data for development.
/// Uncomment Firebase imports and implementations when connecting to real Firebase.

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/store_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import 'mock_data_service.dart';

class FirebaseService {
  // Singleton
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // ============================================================
  // AUTH SERVICES
  // ============================================================

  /// Sign in with email and password
  /// When Firebase is connected, replace with:
  /// ```dart
  /// final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
  ///   email: email, password: password,
  /// );
  /// return credential.user;
  /// ```
  Future<UserModel?> signInWithEmail(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    return MockDataService.getMockCustomer();
  }

  /// Register with email and password
  /// When Firebase is connected:
  /// ```dart
  /// final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
  ///   email: email, password: password,
  /// );
  /// await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
  ///   'name': name, 'email': email, 'phone': phone,
  ///   'role': 'customer', 'createdAt': FieldValue.serverTimestamp(),
  /// });
  /// ```
  Future<UserModel?> registerWithEmail({
    required String name,
    required String email,
    required String password,
    required String phone,
    String address = '',
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return UserModel(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      phone: phone,
      address: address,
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );
  }

  /// Sign out
  Future<void> signOut() async {
    // await FirebaseAuth.instance.signOut();
  }

  // ============================================================
  // FIRESTORE - STORES
  // ============================================================

  /// Get all stores
  /// When Firebase is connected:
  /// ```dart
  /// final snapshot = await FirebaseFirestore.instance
  ///   .collection('stores')
  ///   .where('isOpen', isEqualTo: true)
  ///   .orderBy('rating', descending: true)
  ///   .get();
  /// return snapshot.docs.map((doc) => StoreModel.fromMap({...doc.data(), 'id': doc.id})).toList();
  /// ```
  Future<List<StoreModel>> getStores() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockDataService.getMockStores();
  }

  /// Get store by ID
  Future<StoreModel?> getStore(String storeId) async {
    final stores = MockDataService.getMockStores();
    try {
      return stores.firstWhere((s) => s.id == storeId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // FIRESTORE - PRODUCTS
  // ============================================================

  /// Get products for a store
  /// When Firebase is connected:
  /// ```dart
  /// final snapshot = await FirebaseFirestore.instance
  ///   .collection('stores').doc(storeId)
  ///   .collection('products')
  ///   .where('isAvailable', isEqualTo: true)
  ///   .orderBy('category')
  ///   .get();
  /// return snapshot.docs.map((doc) => ProductModel.fromMap({...doc.data(), 'id': doc.id})).toList();
  /// ```
  Future<List<ProductModel>> getProducts(String storeId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return MockDataService.getMockProducts(storeId);
  }

  /// Add a product (merchant)
  /// ```dart
  /// await FirebaseFirestore.instance
  ///   .collection('stores').doc(product.storeId)
  ///   .collection('products').doc(product.id)
  ///   .set(product.toMap());
  /// ```
  Future<void> addProduct(ProductModel product) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Update a product (merchant)
  Future<void> updateProduct(ProductModel product) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Delete a product (merchant)
  Future<void> deleteProduct(String storeId, String productId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  // ============================================================
  // FIRESTORE - ORDERS
  // ============================================================

  /// Place a new order
  /// When Firebase is connected:
  /// ```dart
  /// final docRef = FirebaseFirestore.instance.collection('orders').doc();
  /// final order = OrderModel(id: docRef.id, ...);
  /// await docRef.set(order.toMap());
  /// return order;
  /// ```
  Future<OrderModel> placeOrder(OrderModel order) async {
    await Future.delayed(const Duration(seconds: 1));
    return order;
  }

  /// Get user orders
  /// ```dart
  /// final snapshot = await FirebaseFirestore.instance
  ///   .collection('orders')
  ///   .where('userId', isEqualTo: userId)
  ///   .orderBy('createdAt', descending: true)
  ///   .get();
  /// ```
  Future<List<OrderModel>> getUserOrders(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockDataService.getMockOrders();
  }

  /// Get store orders (merchant)
  /// ```dart
  /// final snapshot = await FirebaseFirestore.instance
  ///   .collection('orders')
  ///   .where('storeId', isEqualTo: storeId)
  ///   .orderBy('createdAt', descending: true)
  ///   .get();
  /// ```
  Future<List<OrderModel>> getStoreOrders(String storeId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return MockDataService.getMockOrders()
        .where((o) => o.storeId == storeId)
        .toList();
  }

  /// Update order status
  /// ```dart
  /// await FirebaseFirestore.instance
  ///   .collection('orders').doc(orderId)
  ///   .update({
  ///     'status': status.name,
  ///     'updatedAt': FieldValue.serverTimestamp(),
  ///   });
  /// ```
  Future<void> updateOrderStatus(
      String orderId, OrderStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Listen to order status changes (real-time)
  /// ```dart
  /// return FirebaseFirestore.instance
  ///   .collection('orders').doc(orderId)
  ///   .snapshots()
  ///   .map((doc) => OrderModel.fromMap({...doc.data()!, 'id': doc.id}));
  /// ```
  Stream<OrderModel?> watchOrder(String orderId) {
    // Mock: return a stream that emits once
    return Stream.value(null);
  }

  /// Listen to store orders (real-time for merchant)
  /// ```dart
  /// return FirebaseFirestore.instance
  ///   .collection('orders')
  ///   .where('storeId', isEqualTo: storeId)
  ///   .where('status', isEqualTo: 'pending')
  ///   .snapshots()
  ///   .map((snapshot) => snapshot.docs
  ///     .map((doc) => OrderModel.fromMap({...doc.data(), 'id': doc.id}))
  ///     .toList());
  /// ```
  Stream<List<OrderModel>> watchStoreOrders(String storeId) {
    return Stream.value([]);
  }

  // ============================================================
  // FIREBASE STORAGE
  // ============================================================

  /// Upload product image
  /// ```dart
  /// final ref = FirebaseStorage.instance
  ///   .ref('products/$storeId/${DateTime.now().millisecondsSinceEpoch}.jpg');
  /// await ref.putFile(imageFile);
  /// return await ref.getDownloadURL();
  /// ```
  Future<String> uploadProductImage(String storeId, String filePath) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=300';
  }

  // ============================================================
  // FIREBASE CLOUD MESSAGING
  // ============================================================

  /// Initialize FCM and get token
  /// ```dart
  /// final messaging = FirebaseMessaging.instance;
  /// await messaging.requestPermission();
  /// final token = await messaging.getToken();
  /// // Save token to user document
  /// await FirebaseFirestore.instance
  ///   .collection('users').doc(userId)
  ///   .update({'fcmToken': token});
  /// ```
  Future<String?> initializeMessaging(String userId) async {
    return null;
  }

  /// Send notification to merchant when new order is placed
  /// This would typically be done via Cloud Functions:
  /// ```typescript
  /// exports.onNewOrder = functions.firestore
  ///   .document('orders/{orderId}')
  ///   .onCreate(async (snap, context) => {
  ///     const order = snap.data();
  ///     const storeDoc = await admin.firestore()
  ///       .collection('stores').doc(order.storeId).get();
  ///     const ownerDoc = await admin.firestore()
  ///       .collection('users').doc(storeDoc.data().ownerId).get();
  ///     const token = ownerDoc.data().fcmToken;
  ///     await admin.messaging().send({
  ///       token: token,
  ///       notification: { title: 'طلب جديد!', body: `طلب من ${order.userName}` },
  ///       data: { orderId: context.params.orderId },
  ///     });
  ///   });
  /// ```
  Future<void> sendNewOrderNotification(String storeId, String orderId) async {
    // Handled by Cloud Functions
  }
}
