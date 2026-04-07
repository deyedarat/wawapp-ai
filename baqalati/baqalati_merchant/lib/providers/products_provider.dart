import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../services/mock_data_service.dart';

class ProductsProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  bool _isLoading = false;

  List<ProductModel> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;

  int get totalProducts => _products.length;
  int get availableProducts => _products.where((p) => p.isAvailable).length;

  Future<void> loadProducts(String storeId) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _products = MockDataService.getMockProducts(storeId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addProduct(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _products.insert(0, product);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProduct(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _products[index] = product;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteProduct(String productId) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _products.removeWhere((p) => p.id == productId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleAvailability(String productId) async {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index >= 0) {
      _products[index] = _products[index].copyWith(
        isAvailable: !_products[index].isAvailable,
      );
      notifyListeners();
    }
  }
}
