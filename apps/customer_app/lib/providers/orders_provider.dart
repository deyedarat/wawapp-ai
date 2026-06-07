import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Provider managing orders state for the customer app.
class CustomerOrdersProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  List<OrderModel> _activeOrders = [];
  List<OrderModel> _allOrders = [];
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription? _activeOrdersSubscription;
  StreamSubscription? _allOrdersSubscription;

  List<OrderModel> get activeOrders => _activeOrders;
  List<OrderModel> get allOrders => _allOrders;
  List<OrderModel> get orderHistory => _allOrders
      .where((o) =>
          o.status == OrderStatus.delivered || o.status == OrderStatus.cancelled)
      .toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initializes the orders stream for a customer.
  void initializeForCustomer(String customerId) {
    _isLoading = true;
    notifyListeners();

    _activeOrdersSubscription?.cancel();
    _activeOrdersSubscription = _firestoreService
        .streamActiveCustomerOrders(customerId)
        .listen(
      (orders) {
        _activeOrders = orders;
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

    _allOrdersSubscription?.cancel();
    _allOrdersSubscription = _firestoreService
        .streamCustomerOrders(customerId)
        .listen(
      (orders) {
        _allOrders = orders;
        notifyListeners();
      },
    );
  }

  /// Submits a rating for an order.
  Future<bool> rateOrder({
    required String orderId,
    required String customerId,
    required String laundryId,
    required int rating,
    String? comment,
  }) async {
    try {
      final ratingModel = RatingModel(
        id: '',
        orderId: orderId,
        customerId: customerId,
        laundryId: laundryId,
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );

      await _firestoreService.addRating(ratingModel);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _activeOrdersSubscription?.cancel();
    _allOrdersSubscription?.cancel();
    super.dispose();
  }
}
