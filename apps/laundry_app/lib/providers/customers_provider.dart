import 'package:flutter/material.dart';
import 'package:shared/shared.dart';

/// Provider managing customers state for the laundry owner app.
class CustomersProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  List<UserModel> _customers = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  List<UserModel> get customers => _customers;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  /// Loads all customers.
  Future<void> loadCustomers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _customers = await _firestoreService.getCustomers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Searches customers by phone number.
  Future<void> searchByPhone(String phone) async {
    if (phone.isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      final formattedPhone = phone.startsWith('+222')
          ? phone
          : '+222$phone';
      _searchResults = await _firestoreService.searchCustomersByPhone(formattedPhone);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Creates a new customer.
  Future<UserModel?> createCustomer({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final formattedPhone = Validators.formatPhoneNumber(phoneNumber);

      // Check if customer already exists
      final existing = await _authService.getUserByPhone(formattedPhone);
      if (existing != null) {
        _isLoading = false;
        notifyListeners();
        return existing;
      }

      // Create a placeholder user document (they'll complete auth on their app)
      final userId = formattedPhone.replaceAll('+', '');
      final customer = UserModel(
        uid: userId,
        phoneNumber: formattedPhone,
        name: name,
        role: UserRole.customer,
        createdAt: DateTime.now(),
      );

      await _authService.createOrUpdateUser(customer);
      _customers.insert(0, customer);

      _isLoading = false;
      notifyListeners();
      return customer;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Gets order count for a customer.
  Future<int> getCustomerOrderCount(String customerId) async {
    return await _firestoreService.getCustomerOrderCount(customerId);
  }

  /// Clears search results.
  void clearSearch() {
    _searchResults = [];
    _isSearching = false;
    notifyListeners();
  }
}
