import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _checkPhone() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use E.164 format like +222...')),
      );
      return;
    }

    setState(() => _checkingPhone = true);
    final exists =
        await ref.read(authProvider.notifier).checkPhoneExists(phone);
    setState(() {
      _checkingPhone = false;
      _isNewUser = !exists;
    });
  }

  Future<void> _loginWithPin() async {
    if (_pin.text.length != 4) return;
    final phone = _phone.text.trim();
    await ref.read(authProvider.notifier).loginByPin(_pin.text, phone);
  }

  Future<void> _createAccount() async {
    final phone = _phone.text.trim();
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

      if (next.user != null && next.hasPin && !next.isLoading) {
        debugPrint(
            '[LoginScreen] User authenticated with PIN, navigating to home');
        
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
        
        context.go('/');
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
              decoration: const InputDecoration(labelText: 'Phone (+222...)'),
              onChanged: (_) => setState(() => _isNewUser = false),
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
