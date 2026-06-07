import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared/shared.dart';

/// Authentication state for the customer app.
enum CustomerAuthState {
  initial,
  loading,
  codeSent,
  verifying,
  authenticated,
  profileSetup,
  error,
}

/// Provider managing authentication state for the customer app.
class CustomerAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final MessagingService _messagingService = MessagingService();

  CustomerAuthState _state = CustomerAuthState.initial;
  UserModel? _currentUser;
  String? _verificationId;
  int? _resendToken;
  String? _errorMessage;
  String _phoneNumber = '';

  CustomerAuthState get state => _state;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String get phoneNumber => _phoneNumber;
  bool get isAuthenticated => _state == CustomerAuthState.authenticated;

  /// Initializes auth state by checking current user.
  Future<void> initialize() async {
    _state = CustomerAuthState.loading;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user != null) {
        _currentUser = await _authService.getUserProfile(user.uid);
        if (_currentUser != null && _currentUser!.role == UserRole.customer) {
          // Update FCM token
          final token = await _messagingService.initialize();
          if (token != null) {
            await _authService.updateFcmToken(user.uid, token);
          }
          _state = CustomerAuthState.authenticated;
        } else if (_currentUser == null) {
          _state = CustomerAuthState.profileSetup;
        } else {
          await _authService.signOut();
          _state = CustomerAuthState.initial;
        }
      } else {
        _state = CustomerAuthState.initial;
      }
    } catch (e) {
      _state = CustomerAuthState.error;
      _errorMessage = e.toString();
    }

    notifyListeners();
  }

  /// Sends OTP to the given phone number.
  Future<void> sendOtp(String phoneNumber) async {
    _state = CustomerAuthState.loading;
    _phoneNumber = phoneNumber;
    _errorMessage = null;
    notifyListeners();

    final formattedPhone = Validators.formatPhoneNumber(phoneNumber);

    await _authService.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      onVerificationCompleted: (credential) async {
        await _signInWithCredential(credential);
      },
      onVerificationFailed: (e) {
        _state = CustomerAuthState.error;
        _errorMessage = _getErrorMessage(e);
        notifyListeners();
      },
      onCodeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _state = CustomerAuthState.codeSent;
        notifyListeners();
      },
      onCodeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
      resendToken: _resendToken,
    );
  }

  /// Verifies the OTP code.
  Future<void> verifyOtp(String otpCode) async {
    if (_verificationId == null) return;

    _state = CustomerAuthState.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      final userCredential = await _authService.signInWithOTP(
        verificationId: _verificationId!,
        otpCode: otpCode,
      );

      await _handleSignIn(userCredential);
    } on FirebaseAuthException catch (e) {
      _state = CustomerAuthState.codeSent;
      _errorMessage = _getErrorMessage(e);
      notifyListeners();
    } catch (e) {
      _state = CustomerAuthState.codeSent;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Completes profile setup for new customers.
  Future<void> completeProfile(String name) async {
    _state = CustomerAuthState.loading;
    notifyListeners();

    try {
      final user = _authService.currentUser!;
      final formattedPhone = Validators.formatPhoneNumber(_phoneNumber);

      final userModel = UserModel(
        uid: user.uid,
        phoneNumber: formattedPhone,
        name: name,
        role: UserRole.customer,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      await _authService.createOrUpdateUser(userModel);
      _currentUser = userModel;

      // Initialize messaging
      final token = await _messagingService.initialize();
      if (token != null) {
        await _authService.updateFcmToken(user.uid, token);
      }

      _state = CustomerAuthState.authenticated;
      notifyListeners();
    } catch (e) {
      _state = CustomerAuthState.profileSetup;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _state = CustomerAuthState.initial;
    _verificationId = null;
    _resendToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Resends the OTP code.
  Future<void> resendOtp() async {
    await sendOtp(_phoneNumber);
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _handleSignIn(userCredential);
    } catch (e) {
      _state = CustomerAuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> _handleSignIn(UserCredential userCredential) async {
    final user = userCredential.user!;
    _currentUser = await _authService.getUserProfile(user.uid);

    if (_currentUser != null) {
      // Update last login
      await _authService.createOrUpdateUser(
        _currentUser!.copyWith(lastLoginAt: DateTime.now()),
      );

      final token = await _messagingService.initialize();
      if (token != null) {
        await _authService.updateFcmToken(user.uid, token);
      }

      _state = CustomerAuthState.authenticated;
    } else {
      _state = CustomerAuthState.profileSetup;
    }

    notifyListeners();
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'رقم الهاتف غير صحيح';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'invalid-verification-code':
        return 'رمز التحقق غير صحيح';
      case 'session-expired':
        return 'انتهت صلاحية الرمز، أعد المحاولة';
      default:
        return 'حدث خطأ: ${e.message}';
    }
  }
}
