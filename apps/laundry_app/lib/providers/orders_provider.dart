import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Provider managing orders state for the laundry owner app.
class OrdersProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<OrderModel> _allOrders = [];
  List<OrderModel> _todayOrders = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _ordersSubscription;
  StreamSubscription? _todaySubscription;

  List<OrderModel> get allOrders => _allOrders;
  List<OrderModel> get todayOrders => _todayOrders;
  Map<String, int> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<OrderModel> get pendingOrders => _allOrders
      .where((o) =>
          o.status == OrderStatus.received || o.status == OrderStatus.washing)
      .toList();

  List<OrderModel> get readyOrders =>
      _allOrders.where((o) => o.status == OrderStatus.ready).toList();

  List<OrderModel> get deliveredTodayOrders => _todayOrders
      .where((o) => o.status == OrderStatus.delivered)
      .toList();

  /// Initializes the orders stream for a laundry.
  void initializeForLaundry(String laundryId) {
    _isLoading = true;
    notifyListeners();

    _ordersSubscription?.cancel();
    _ordersSubscription = _firestoreService
        .streamLaundryOrders(laundryId)
        .listen(
      (orders) {
        _allOrders = orders;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );

    _todaySubscription?.cancel();
    _todaySubscription = _firestoreService
        .streamTodayOrders(laundryId)
        .listen(
      (orders) {
        _todayOrders = orders;
        _updateStats();
        notifyListeners();
      },
    );
  }

  /// Creates a new order.
  Future<String?> createOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String laundryId,
    required List<OrderItemModel> items,
    required double totalPrice,
    required DateTime estimatedCompletionTime,
    required String staffId,
    double? discount,
    String? notes,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final order = OrderModel(
        id: '',
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        laundryId: laundryId,
        items: items,
        status: OrderStatus.received,
        totalPrice: totalPrice,
        discount: discount,
        createdAt: DateTime.now(),
        estimatedCompletionTime: estimatedCompletionTime,
        notes: notes,
        createdByStaffId: staffId,
      );

      final orderId = await _firestoreService.createOrder(order);
      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Updates order status.
  Future<bool> updateOrderStatus(String orderId, OrderStatus status) async {
    try {
      await _firestoreService.updateOrderStatus(orderId, status);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Gets revenue for a date range.
  Future<double> getRevenue(String laundryId, DateTime start, DateTime end) async {
    return await _firestoreService.getRevenue(laundryId, start, end);
  }

  void _updateStats() {
    int pending = 0;
    int ready = 0;
    int delivered = 0;

    for (final order in _todayOrders) {
      switch (order.status) {
        case OrderStatus.received:
        case OrderStatus.washing:
          pending++;
          break;
        case OrderStatus.ready:
          ready++;
          break;
        case OrderStatus.delivered:
          delivered++;
          break;
        case OrderStatus.cancelled:
          break;
      }
    }

    _stats = {
      'pending': pending,
      'ready': ready,
      'delivered': delivered,
      'total': _todayOrders.length,
    };
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _todaySubscription?.cancel();
    super.dispose();
  }
}
