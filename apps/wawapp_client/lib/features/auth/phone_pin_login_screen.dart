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
  bool _navigatedThisAttempt = false;
  ProviderSubscription<AuthState>? _cancelListener;

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
      // ✅ نفّذ النداء فورًا بالحالة الحالية
      fireImmediately: true,
    );
    _cancelListener = cancel;
    // ✅ تأمين إضافي: لو fireImmediately غير مدعومة/لم تُطلق التنقّل،
    //   نفّذ على الحالة الحالية بعد إنشائه مباشرة.
    Future.microtask(() {
      final current = ref.read(authProvider);
      _onAuthState(prev: null, next: current);
    });
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

      debugPrint(
          '[PhonePinLogin] Navigating to OtpScreen (codeSent, vid=${next.verificationId?.substring(next.verificationId!.length - 6)})');

      // ✅ أي pending-loading UI لازم يتوقف الآن
      Future.microtask(() {
        if (!mounted || _navigatedThisAttempt == false) return;
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
      });
    }

    // Navigate home when authenticated
    if (next.user != null && !next.isLoading && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelListener?.close();
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
    // Navigation handled by listener

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
