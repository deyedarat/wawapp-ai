import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers/auth_service_provider.dart';
import 'otp_screen.dart';

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

  Future<void> _continue() async {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164.hasMatch(phone)) {
      setState(
          () => _err = 'Invalid phone format. Use E.164 like +22212345678');
      return;
    }
    setState(() => _err = null);

    if (kDebugMode) {
      print('[PhonePinLogin] Attempting login');
    }

    await ref.read(authProvider.notifier).sendOtp(phone);

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.error != null) {
      if (kDebugMode) {
        print('[PhonePinLogin] Error after sendOtp: ${authState.error}');
      }
      return; // Error will be shown from authState
    }

    if (FirebaseAuth.instance.currentUser == null) {
      if (kDebugMode) {
        print('[PhonePinLogin] Not signed in, navigating to OTP');
      }

      if (!context.mounted) {
        return;
      }
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const OtpScreen()));
      return;
    }

    if (_pin.text.length != 4) {
      setState(() => _err = 'PIN must be 4 digits');
      return;
    }

    if (kDebugMode) {
      print('[PhonePinLogin] Verifying PIN');
    }

    await ref.read(authProvider.notifier).loginByPin(_pin.text);

    if (kDebugMode) {
      print('[PhonePinLogin] loginByPin call completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for successful login and navigate
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.hasPin && !next.isLoading && next.user != null) {
        if (kDebugMode) {
          print('[PhonePinLogin] Login success');
        }
        Navigator.pop(context);
      }
      if (next.error != null && previous?.error != next.error) {
        if (kDebugMode) {
          print('[PhonePinLogin] Error: ${next.error}');
        }
      }
    });

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
                onPressed: authState.isLoading ? null : _continue,
                child: const Text('Continue')),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      final phone = _phone.text.trim();
                      final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
                      if (!e164.hasMatch(phone)) {
                        setState(() => _err =
                            'Invalid phone format. Use E.164 like +22212345678');
                        return;
                      }
                      setState(() => _err = null);

                      if (kDebugMode) {
                        print('[PhonePinLogin] SMS verification requested');
                      }

                      await ref.read(authProvider.notifier).sendOtp(phone);

                      if (!mounted) {
                        return;
                      }

                      if (!context.mounted) {
                        return;
                      }
                      await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const OtpScreen()));
                    },
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
