import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'providers/auth_service_provider.dart';
import 'package:auth_shared/auth_shared.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() =>
      _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _isNewUser = false;
  bool _checkingPhone = false;
  String? _phoneError;
  bool _navigationInProgress = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _checkPhone() async {
    final phone = _phone.text.trim();
    
    // Validate and convert to E.164 format
    String phoneE164;
    try {
      if (phone.startsWith('+')) {
        // Already in E.164, validate it
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() {
            _phoneError = 'رقم هاتف غير صحيح بصيغة +222';
          });
          return;
        }
        phoneE164 = phone;
      } else {
        // Local format, validate and convert
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() {
            _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
          });
          return;
        }
        phoneE164 = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      }
    } catch (e) {
      setState(() {
        _phoneError = 'رقم هاتف غير صحيح';
      });
      return;
    }

    setState(() {
      _checkingPhone = true;
      _phoneError = null;
    });
    
    final exists =
        await ref.read(authProvider.notifier).checkPhoneExists(phoneE164);
    setState(() {
      _checkingPhone = false;
      _isNewUser = !exists;
      // Update the text field with E.164 format for clarity
      _phone.text = phoneE164;
    });
  }

  Future<void> _loginWithPin() async {
    if (_pin.text.length != 4) return;

    String phone = _phone.text.trim();

    // Ensure phone is in E.164 format
    if (!phone.startsWith('+')) {
      try {
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      } catch (e) {
        setState(() {
          _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
        });
        return;
      }
    }

    await ref.read(authProvider.notifier).loginByPin(_pin.text);
  }

  Future<void> _createAccount() async {
    String phone = _phone.text.trim();
    
    // Ensure phone is in E.164 format
    if (!phone.startsWith('+')) {
      try {
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      } catch (e) {
        setState(() {
          _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
        });
        return;
      }
    }
    
    debugPrint('[LoginScreen] _createAccount() called for phone=$phone');

    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      debugPrint('[LoginScreen] sendOtp() returned successfully');
    } catch (e, stackTrace) {
      debugPrint(
          '[LoginScreen] sendOtp() threw exception: ${e.runtimeType} - $e');
      debugPrint('[LoginScreen] Stacktrace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      debugPrint(
          '[LoginScreen] Auth state changed: otpStage=${next.otpStage}, otpFlowActive=${next.otpFlowActive}, verificationId isNull=${next.verificationId == null}, error=${next.error}');

      if (next.otpStage == OtpStage.codeSent) {
        debugPrint(
            '[LoginScreen] OTP code sent, router will redirect based on canOtp.');
      }

      if (next.error != null && next.error!.isNotEmpty) {
        debugPrint('[LoginScreen] Error detected in auth state: ${next.error}');
      }

      if (next.user != null && !next.isLoading && !_navigationInProgress) {
        _navigationInProgress = true;

        debugPrint(
            '[LoginScreen] User authenticated, routing to AuthGate - user=${next.user!.uid} hasPin=${next.hasPin}');

        // Crashlytics breadcrumb
        FirebaseCrashlytics.instance.log('[LoginScreen] Navigation triggered: PIN login successful');
        FirebaseCrashlytics.instance.setCustomKey('nav_attempt', 'pin_login_success');
        FirebaseCrashlytics.instance.setCustomKey('route_from', '/login');
        FirebaseCrashlytics.instance.setCustomKey('route_to', '/');

        // Schedule side-effects after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Set basic user properties immediately after auth
            AnalyticsService.instance.setUserProperties(userId: next.user!.uid);
            AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');

            // Initialize FCM for push notifications
            FCMService.instance.initialize(context);

            // ANALYTICS VALIDATION:
            // To verify this event in Firebase Console:
            // 1. Run: adb shell setprop debug.firebase.analytics.app com.wawapp.client
            // 2. Open Firebase Console → Analytics → DebugView
            // 3. Complete auth flow and verify:
            //    - Event: auth_completed (method: phone_pin)
            //    - User property: user_type = client
            //    - User ID is set

            debugPrint('[LoginScreen] Executing deferred navigation to /');
            context.go('/');
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (8 أرقام)',
                helperText: 'مثال: 22123456 أو +22222123456',
                errorText: _phoneError,
                prefixText: _phone.text.startsWith('+') ? '' : '+222 ',
              ),
              onChanged: (_) => setState(() {
                _isNewUser = false;
                _phoneError = null;
              }),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkingPhone ? null : _checkPhone,
              child: _checkingPhone
                  ? const CircularProgressIndicator()
                  : const Text('Check Phone'),
            ),
            const SizedBox(height: 16),
            if (_isNewUser) ...[
              const Text('New user - Create account'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _createAccount,
                child: const Text('Create Account'),
              ),
            ] else if (!_isNewUser && _phone.text.isNotEmpty) ...[
              const Text('Existing user - Enter PIN'),
              TextField(
                controller: _pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _loginWithPin,
                child: const Text('Login'),
              ),
            ],
            if (authState.error != null)
              Text(authState.error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
