import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../models/rating_model.dart';
import '../constants/firestore_paths.dart';
import '../constants/app_constants.dart';

/// Service handling all Firestore database operations.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ==================== ORDER OPERATIONS ====================

  /// Creates a new order.
  Future<String> createOrder(OrderModel order) async {
    final docRef = await _firestore
        .collection(FirestorePaths.orders)
        .add(order.toFirestore());
    return docRef.id;
  }

  /// Updates an existing order.
  Future<void> updateOrder(String orderId, Map<String, dynamic> data) async {
    await _firestore
        .collection(FirestorePaths.orders)
        .doc(orderId)
        .update(data);
  }

  /// Updates order status.
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final Map<String, dynamic> data = {'status': status.name};

    if (status == OrderStatus.ready) {
      data['completedAt'] = Timestamp.now();
    } else if (status == OrderStatus.delivered) {
      data['deliveredAt'] = Timestamp.now();
    }

    await updateOrder(orderId, data);
  }

  /// Gets a single order by ID.
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore
        .collection(FirestorePaths.orders)
        .doc(orderId)
        .get();
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  /// Streams a single order.
  Stream<OrderModel?> streamOrder(String orderId) {
    return _firestore
        .collection(FirestorePaths.orders)
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  /// Streams orders for a specific laundry.
  Stream<List<OrderModel>> streamLaundryOrders(String laundryId, {OrderStatus? status}) {
    Query query = _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldLaundryId, isEqualTo: laundryId)
        .orderBy(FirestorePaths.fieldCreatedAt, descending: true);

    if (status != null) {
      query = query.where(FirestorePaths.fieldStatus, isEqualTo: status.name);
    }

    return query.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  /// Streams orders for a specific customer.
  Stream<List<OrderModel>> streamCustomerOrders(String customerId) {
    return _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldCustomerId, isEqualTo: customerId)
        .orderBy(FirestorePaths.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  /// Gets active orders for a customer.
  Stream<List<OrderModel>> streamActiveCustomerOrders(String customerId) {
    return _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldCustomerId, isEqualTo: customerId)
        .where(FirestorePaths.fieldStatus, whereIn: [
          OrderStatus.received.name,
          OrderStatus.washing.name,
          OrderStatus.ready.name,
        ])
        .orderBy(FirestorePaths.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  /// Gets orders for today (for dashboard).
  Stream<List<OrderModel>> streamTodayOrders(String laundryId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldLaundryId, isEqualTo: laundryId)
        .where(FirestorePaths.fieldCreatedAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .orderBy(FirestorePaths.fieldCreatedAt, descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList());
  }

  /// Gets revenue for a date range.
  Future<double> getRevenue(String laundryId, DateTime start, DateTime end) async {
    final query = await _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldLaundryId, isEqualTo: laundryId)
        .where(FirestorePaths.fieldStatus, isEqualTo: OrderStatus.delivered.name)
        .where('deliveredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('deliveredAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return query.docs.fold(0.0, (sum, doc) {
      final data = doc.data();
      return sum + (data['totalPrice'] ?? 0).toDouble();
    });
  }

  // ==================== CUSTOMER OPERATIONS ====================

  /// Gets all customers for a laundry.
  Future<List<UserModel>> getCustomers({int limit = 50}) async {
    final query = await _firestore
        .collection(FirestorePaths.users)
        .where(FirestorePaths.fieldRole, isEqualTo: UserRole.customer.name)
        .where(FirestorePaths.fieldIsActive, isEqualTo: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Searches customers by phone number.
  Future<List<UserModel>> searchCustomersByPhone(String phoneQuery) async {
    final query = await _firestore
        .collection(FirestorePaths.users)
        .where(FirestorePaths.fieldRole, isEqualTo: UserRole.customer.name)
        .where(FirestorePaths.fieldPhoneNumber,
            isGreaterThanOrEqualTo: phoneQuery)
        .where(FirestorePaths.fieldPhoneNumber,
            isLessThanOrEqualTo: '$phoneQuery\uf8ff')
        .limit(10)
        .get();

    return query.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  /// Gets order count for a customer.
  Future<int> getCustomerOrderCount(String customerId) async {
    final query = await _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldCustomerId, isEqualTo: customerId)
        .count()
        .get();
    return query.count ?? 0;
  }

  // ==================== RATING OPERATIONS ====================

  /// Adds a rating for an order.
  Future<void> addRating(RatingModel rating) async {
    await _firestore
        .collection(FirestorePaths.ratings)
        .add(rating.toFirestore());

    // Also update the order with the rating
    await updateOrder(rating.orderId, {
      'rating': rating.rating,
      'ratingComment': rating.comment,
    });
  }

  /// Gets average rating for a laundry.
  Future<double> getLaundryAverageRating(String laundryId) async {
    final query = await _firestore
        .collection(FirestorePaths.ratings)
        .where('laundryId', isEqualTo: laundryId)
        .get();

    if (query.docs.isEmpty) return 0.0;

    final totalRating = query.docs.fold(0, (sum, doc) {
      final data = doc.data();
      return sum + (data['rating'] as int? ?? 0);
    });

    return totalRating / query.docs.length;
  }

  // ==================== STATS OPERATIONS ====================

  /// Gets order statistics for dashboard.
  Future<Map<String, int>> getOrderStats(String laundryId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final todayOrders = await _firestore
        .collection(FirestorePaths.orders)
        .where(FirestorePaths.fieldLaundryId, isEqualTo: laundryId)
        .where(FirestorePaths.fieldCreatedAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    int pending = 0;
    int ready = 0;
    int delivered = 0;

    for (final doc in todayOrders.docs) {
      final status = doc.data()['status'] as String?;
      switch (status) {
        case 'received':
        case 'washing':
          pending++;
          break;
        case 'ready':
          ready++;
          break;
        case 'delivered':
          delivered++;
          break;
      }
    }

    return {
      'pending': pending,
      'ready': ready,
      'delivered': delivered,
      'total': todayOrders.docs.length,
    };
  }
}
