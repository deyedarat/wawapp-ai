import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../services/mock_data_service.dart';

class OrdersProvider extends ChangeNotifier {
  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;

  List<OrderModel> get activeOrders => _orders
      .where((o) =>
          o.status != OrderStatus.delivered &&
          o.status != OrderStatus.cancelled)
      .toList();

  List<OrderModel> get completedOrders => _orders
      .where((o) =>
          o.status == OrderStatus.delivered ||
          o.status == OrderStatus.cancelled)
      .toList();

  // Orders for a specific store (merchant view)
  List<OrderModel> getStoreOrders(String storeId) {
    return _orders.where((o) => o.storeId == storeId).toList();
  }

  List<OrderModel> getStoreTodayOrders(String storeId) {
    final today = DateTime.now();
    return _orders.where((o) =>
        o.storeId == storeId &&
        o.createdAt.year == today.year &&
        o.createdAt.month == today.month &&
        o.createdAt.day == today.day).toList();
  }

  double getStoreTodayRevenue(String storeId) {
    return getStoreTodayOrders(storeId)
        .where((o) => o.status != OrderStatus.cancelled)
        .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _orders = MockDataService.getMockOrders();
    _isLoading = false;
    notifyListeners();
  }

  Future<OrderModel> placeOrder({
    required String userId,
    required String userName,
    required String userPhone,
    required String storeId,
    required String storeName,
    required List<CartItem> items,
    required double totalAmount,
    required DeliveryType deliveryType,
    String deliveryAddress = '',
    String notes = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    final order = OrderModel(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      userId: userId,
      userName: userName,
      userPhone: userPhone,
      storeId: storeId,
      storeName: storeName,
      items: items,
      totalAmount: totalAmount,
      status: OrderStatus.pending,
      deliveryType: deliveryType,
      deliveryAddress: deliveryAddress,
      notes: notes,
      createdAt: DateTime.now(),
    );

    _orders.insert(0, order);
    _isLoading = false;
    notifyListeners();
    return order;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index >= 0) {
      _orders[index] = _orders[index].copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }
}
