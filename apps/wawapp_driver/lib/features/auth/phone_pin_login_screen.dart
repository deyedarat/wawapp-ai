import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_service_provider.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() =>
      _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _handleOtpFlow() async {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');

    if (!e164.hasMatch(phone)) {
      setState(() => _err = 'Invalid phone format. Use E.164 like +22212345678');
      return;
    }

    setState(() => _err = null);

    if (kDebugMode) {
      print('[PhonePinLogin] Starting OTP flow with phone: $phone');
    }

    // Mark OTP flow as active in provider (survives rebuild)
    ref.read(authProvider.notifier).startOtpFlow();

    // Send OTP - AuthGate will automatically show OTP screen when otpStage = codeSent
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (kDebugMode) {
        print('[PhonePinLogin] OTP sent, AuthGate will show OTP screen');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[PhonePinLogin] OTP send failed: $e');
      }
      // Error is already set in provider state
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final errorMessage = _err ?? authState.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (+222...)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'PIN (4 digits)'),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (authState.isLoading ||
                      authState.otpStage == OtpStage.sending ||
                      authState.otpStage == OtpStage.codeSent)
                  ? null
                  : _handleOtpFlow,
              child: authState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Continue'),
            ),
            TextButton(
              // IMPORTANT:
              // Always allow the user to tap this link to start SMS verification.
              // The handler validates the phone number and navigates to /otp.
              // The provider has guard logic to prevent duplicate OTP sends.
              onPressed: _handleOtpFlow,
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
