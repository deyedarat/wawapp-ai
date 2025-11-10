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

            if (kDebugMode) {
              print('[PhonePinLogin] Navigating to /otp (codeSent)');
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              // Close IME safely before navigation
              FocusScope.of(context).unfocus();

              if (context.mounted) {
                context.push('/otp');
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

  void _handleOtpFlow() {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');

    if (!e164.hasMatch(phone)) {
      setState(
          () => _err = 'Invalid phone format. Use E.164 like +22212345678');
      return;
    }

    setState(() => _err = null);

    if (kDebugMode) {
      print('[PhonePinLogin] Starting OTP flow (non-await)...');
    }

    // Mark OTP flow as active in provider (survives rebuild)
    ref.read(authProvider.notifier).startOtpFlow();

    // Start sending OTP (no await)
    ref.read(authProvider.notifier).sendOtp(phone);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listener for PIN login (keep existing)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!mounted) return;
      if (next.otpFlowActive) return; // Skip if in OTP flow

      if (next.hasPin && !next.isLoading && next.user != null) {
        if (kDebugMode) {
          print('[PhonePinLogin] Login success');
        }
        if (context.mounted) {
          Navigator.pop(context);
        }
      }

      if (next.error != null && previous?.error != next.error) {
        if (kDebugMode) {
          print('[PhonePinLogin] Error: ${next.error}');
        }
      }
    });

    // OTP navigation handled in initState listenManual

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
              onPressed: authState.isLoading ? null : _handleOtpFlow,
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
