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
  bool _navigatedThisAttempt = false;

  // ✅ Store cancel function
  void Function()? _cancelListener;
  @override
  void initState() {
    super.initState();
    _navigatedThisAttempt = false;
    // ✅ Riverpod-safe listener outside build:
    debugPrint('[PhonePinLogin] 🔵 Setting up listener (manual)');
    final cancel = ref.listenManual<AuthState>(
      authProvider,
      (previous, next) {
        _onAuthState(prev: previous, next: next);
      },
        debugPrint('[PhonePinLogin] 🟡 Listener triggered!');
        debugPrint('[PhonePinLogin] Previous stage: ${previous?.otpStage}');
        debugPrint('[PhonePinLogin] Next stage: ${next.otpStage}');
        debugPrint(
            '[PhonePinLogin] _navigatedThisAttempt: $_navigatedThisAttempt');
        debugPrint('[PhonePinLogin] mounted: $mounted');

      },
      // ✅ نفّذ النداء فورًا بالحالة الحالية
      fireImmediately: true,
    );
    // ✅ تأمين إضافي: لو fireImmediately غير مدعومة/لم تُطلق التنقّل،
    //   نفّذ على الحالة الحالية بعد إنشائه مباشرة.
    Future.microtask(() {
      final current = ref.read(authProvider);
      _onAuthState(prev: null, next: current);
    });
    ref.onDispose(cancel);
  }

  void _onAuthState({AuthState? prev, required AuthState next}) {
    debugPrint('[PhonePinLogin] 🟡 Listener triggered!');
    debugPrint('[PhonePinLogin] Previous stage: ${prev?.otpStage}');
    debugPrint('[PhonePinLogin] Next stage: ${next.otpStage}');
    debugPrint('[PhonePinLogin] _navigatedThisAttempt: $_navigatedThisAttempt');
    debugPrint('[PhonePinLogin] mounted: $mounted');

    // ✅ اعتبرها codeSent حتى في أول استدعاء لو الحالة الحالية بالفعل codeSent
    final becameCodeSent = next.otpStage == OtpStage.codeSent &&
        (prev == null || prev.otpStage != OtpStage.codeSent);

    if (becameCodeSent &&
        !_navigatedThisAttempt &&
        next.phoneE164 != null &&
        next.verificationId != null) {
      debugPrint('[PhonePinLogin] 🟢 Navigation condition MET!');
      _navigatedThisAttempt = true;

      if (!mounted) {
        debugPrint('[PhonePinLogin] ❌ Widget not mounted');
        return;
      }

      // ✅ أي pending-loading UI لازم يتوقف الآن
      Future.microtask(() {
        if (!mounted || _navigatedThisAttempt == false) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !context.mounted) return;
          debugPrint('[PhonePinLogin] 🚀 Attempting navigation to /otp');
          try {
            context.push('/otp', extra: {
              'phone': next.phoneE164!,
              'verificationId': next.verificationId!,
              'resendToken': next.resendToken,
            });
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
      if (prev != null && prev.otpStage == next.otpStage) {
        debugPrint('[PhonePinLogin] Reason: Stage unchanged');
      }
      if (next.otpStage != OtpStage.codeSent) {
        debugPrint('[PhonePinLogin] Reason: Stage is not codeSent');
      }
    }

    // Check for successful login
    if (next.user != null && !next.isLoading && mounted) {
      debugPrint('[PhonePinLogin] User logged in, navigating to home');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !context.mounted) return;
        context.go('/');
      });
    }
  }

  @override
  void dispose() {
    _cancelListener?.call();
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

    // Reset navigation flag for new attempt
    _navigatedThisAttempt = false;

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
              onPressed: (authState.isLoading ||
                      authState.otpStage == OtpStage.sending ||
                      authState.otpStage == OtpStage.codeSent)
                  ? null
                  : _handleOtpFlow,
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
