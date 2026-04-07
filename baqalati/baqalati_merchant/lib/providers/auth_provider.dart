import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/mock_data_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock login - accept any credentials
    _user = MockDataService.getMockCustomer();
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> loginAsMerchant(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _user = MockDataService.getMockMerchant();
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    String address = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _user = UserModel(
      id: 'user_new_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      phone: phone,
      address: address,
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> loginAsGuest() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 500));

    _user = UserModel(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: 'زائر',
      email: '',
      phone: '',
      role: UserRole.customer,
      createdAt: DateTime.now(),
    );
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
  }

  void logout() {
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
