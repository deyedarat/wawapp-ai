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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[PhonePinLogin] 🔵 Setting up listener');

      ref.listen<AuthState>(authProvider, (previous, next) {
        debugPrint('[PhonePinLogin] 🟡 Listener triggered!');
        debugPrint('[PhonePinLogin] Previous stage: ${previous?.otpStage}');
        debugPrint('[PhonePinLogin] Next stage: ${next.otpStage}');
        debugPrint(
            '[PhonePinLogin] _navigatedThisAttempt: $_navigatedThisAttempt');
        debugPrint('[PhonePinLogin] mounted: $mounted');

        // Check navigation condition
        if (!_navigatedThisAttempt &&
            previous?.otpStage != next.otpStage &&
            next.otpStage == OtpStage.codeSent) {
          debugPrint('[PhonePinLogin] 🟢 Navigation condition MET!');
          _navigatedThisAttempt = true;

          if (!mounted) {
            debugPrint('[PhonePinLogin] ❌ Widget not mounted');
            return;
          }

          debugPrint(
              '[PhonePinLogin] ⏳ Starting delayed navigation (800ms)...');

          Future.delayed(const Duration(milliseconds: 800), () {
            debugPrint('[PhonePinLogin] ⏰ Delay completed');

            if (!mounted || !context.mounted) {
              debugPrint('[PhonePinLogin] ❌ Context not mounted after delay');
              return;
            }

            debugPrint('[PhonePinLogin] 🎯 Closing keyboard...');
            FocusScope.of(context).unfocus();

            WidgetsBinding.instance.addPostFrameCallback((_) {
              debugPrint('[PhonePinLogin] 📍 Post frame callback');

              if (!mounted || !context.mounted) {
                debugPrint('[PhonePinLogin] ❌ Context not mounted in callback');
                return;
              }

              debugPrint('[PhonePinLogin] 🚀 Attempting navigation to /otp');
              try {
                context.push('/otp');
                debugPrint('[PhonePinLogin] ✅ Navigation successful!');
              } catch (e, stackTrace) {
                debugPrint('[PhonePinLogin] ❌ Navigation failed: $e');
                debugPrint('[PhonePinLogin] Stack trace: $stackTrace');
              }
            });
          });
        } else {
          debugPrint('[PhonePinLogin] 🔴 Navigation condition NOT met');
          if (_navigatedThisAttempt) {
            debugPrint('[PhonePinLogin] Reason: Already navigated');
          }
          if (previous?.otpStage == next.otpStage) {
            debugPrint('[PhonePinLogin] Reason: Stage unchanged');
          }
          if (next.otpStage != OtpStage.codeSent) {
            debugPrint('[PhonePinLogin] Reason: Stage is not codeSent');
          }
        }

        // Check for successful login (existing code)
        if (next.user != null && !next.isLoading && mounted) {
          debugPrint(
              '[PhonePinLogin] User logged in - AuthGate will handle navigation');
        }
      });
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

    // Listener for PIN login (keep existing)
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!mounted) return;
      if (next.otpFlowActive) return; // Skip if in OTP flow

      if (next.hasPin && !next.isLoading && next.user != null) {
        if (kDebugMode) {
          print(
              '[PhonePinLogin] Login success - AuthGate will handle navigation');
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
