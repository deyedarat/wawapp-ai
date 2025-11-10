import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'otp_screen.dart';
import 'providers/auth_service_provider.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() =>
      _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController(); // e.g. +222xxxxxxxx
  final _pin = TextEditingController();
  String? _err;
  ProviderSubscription<AuthState>? _authSubscription;
  bool _navigatedThisAttempt = false;

  @override
  void initState() {
    super.initState();
    _navigatedThisAttempt = false;
    // Use listenManual for precise control over navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authSubscription = ref.listenManual(
        authProvider,
        (previous, next) {
          // Navigate to OTP screen exactly once when codeSent
          if (!_navigatedThisAttempt &&
              previous?.otpStage != next.otpStage &&
              next.otpStage == OtpStage.codeSent) {
            _navigatedThisAttempt = true;
            if (!mounted) return;

            debugPrint(
                '[PhonePinLogin] Navigating to OtpScreen (codeSent, vid=${next.verificationId?.substring(next.verificationId!.length - 6)})');

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              // Close IME safely before navigation
              FocusScope.of(context).unfocus();

              // Show snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('OTP sent to ${next.phoneE164}')),
              );

              // Navigate to OTP screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OtpScreen(
                    verificationId: next.verificationId!,
                    phone: next.phoneE164!,
                    resendToken: next.resendToken,
                  ),
                ),
              );
            });
          }

          // Navigate home when authenticated
          if (next.user != null && !next.isLoading && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/');
              }
            });
          }
        },
      );
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
    if (!phone.startsWith('+')) {
      setState(() => _err = 'Use E.164 like +222...');
      return;
    }
    setState(() => _err = null);

    // Reset navigation flag for new attempt
    _navigatedThisAttempt = false;
    await ref.read(authProvider.notifier).sendOtp(phone);
    // Navigation handled by router redirect

    if (_pin.text.length != 4) {
      setState(() => _err = 'PIN must be 4 digits');
      return;
    }

    await ref.read(authProvider.notifier).loginByPin(_pin.text);
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
                decoration:
                    const InputDecoration(labelText: 'Phone (+222...)')),
            const SizedBox(height: 12),
            TextField(
                controller: _pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN (4 digits)')),
            if (errorMessage != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: (authState.isLoading ||
                        authState.otpStage == OtpStage.sending ||
                        authState.otpStage == OtpStage.codeSent)
                    ? null
                    : _continue,
                child: authState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Continue')),
          ],
        ),
      ),
    );
  }
}
