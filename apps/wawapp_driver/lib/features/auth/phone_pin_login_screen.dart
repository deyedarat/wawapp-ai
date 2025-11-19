import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  ProviderSubscription<AuthState>? _authSubscription;
  bool _navigatedThisAttempt = false;

  @override
  void initState() {
    super.initState();
    _navigatedThisAttempt = false;

    _authSubscription =
        ref.listenManual<AuthState>(authProvider, (previous, next) {
      if (!_navigatedThisAttempt &&
          previous?.otpStage != next.otpStage &&
          next.otpStage == OtpStage.codeSent) {
        _navigatedThisAttempt = true;

        if (!mounted || !context.mounted) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !context.mounted) return;

          context.push('/otp');
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164.hasMatch(phone)) {
      if (mounted) {
        setState(
            () => _err = 'Invalid phone format. Use E.164 like +22212345678');
      }
      return;
    }

    if (mounted) {
      setState(() => _err = null);
    }

    if (!mounted) return;

    // Reset navigation flag for new attempt
    _navigatedThisAttempt = false;
    await ref.read(authProvider.notifier).sendOtp(phone);
  }

  void _handleOtpFlow() async {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');

    // If phone is empty or invalid, navigate to OTP screen anyway
    // The OTP screen can handle phone input and validation
    if (phone.isEmpty || !e164.hasMatch(phone)) {
      if (kDebugMode) {
        print(
            '[PhonePinLogin] No valid phone, navigating to OTP screen for input');
      }
      context.push('/otp');
      return;
    }

    setState(() => _err = null);

    if (kDebugMode) {
      print('[PhonePinLogin] Starting OTP flow with phone: $phone');
    }

    // Mark OTP flow as active in provider (survives rebuild)
    ref.read(authProvider.notifier).startOtpFlow();

    // Start sending OTP and navigate immediately after
    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (mounted && context.mounted) {
        if (kDebugMode) {
          print('[PhonePinLogin] OTP sent, navigating to /otp');
        }
        context.push('/otp');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PhonePinLogin] OTP send failed: $e');
      }
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
                  : _continue,
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
