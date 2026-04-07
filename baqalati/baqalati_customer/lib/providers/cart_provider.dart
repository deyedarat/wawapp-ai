import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  String? _currentStoreId;
  String? _currentStoreName;

  List<CartItem> get items => List.unmodifiable(_items);
  String? get currentStoreId => _currentStoreId;
  String? get currentStoreName => _currentStoreName;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => _items.isEmpty;

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  void addProduct(ProductModel product, {String? storeName}) {
    // If cart has items from a different store, clear it
    if (_currentStoreId != null && _currentStoreId != product.storeId) {
      _items.clear();
    }

    _currentStoreId = product.storeId;
    if (storeName != null) _currentStoreName = storeName;

    final existingIndex = _items.indexWhere(
      (item) => item.productId == product.id,
    );

    if (existingIndex >= 0) {
      _items[existingIndex].quantity++;
    } else {
      _items.add(CartItem(
        productId: product.id,
        productName: product.name,
        productNameAr: product.nameAr,
        productNameFr: product.nameFr,
        price: product.price,
        unit: product.unitAr,
        quantity: 1,
        imageUrl: product.imageUrl,
      ));
    }
    notifyListeners();
  }

  void removeProduct(String productId) {
    _items.removeWhere((item) => item.productId == productId);
    if (_items.isEmpty) {
      _currentStoreId = null;
      _currentStoreName = null;
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
        if (_items.isEmpty) {
          _currentStoreId = null;
          _currentStoreName = null;
        }
      } else {
        _items[index].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void incrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      _items[index].quantity++;
      notifyListeners();
    }
  }

  void decrementQuantity(String productId) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
        if (_items.isEmpty) {
          _currentStoreId = null;
          _currentStoreName = null;
        }
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    _currentStoreId = null;
    _currentStoreName = null;
    notifyListeners();
  }
}
