import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_service_provider.dart';
import '../../main.dart' show navigatorKey;

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

  Future<void> _continue() async {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
    if (!e164.hasMatch(phone)) {
      if (mounted) {
        setState(() => _err = 'Invalid phone format. Use E.164 like +22212345678');
      }
      return;
    }
    
    if (mounted) {
      setState(() => _err = null);
    }

    if (!mounted) return;
    
    await ref.read(authProvider.notifier).sendOtp(phone);
  }

  void _handleOtpFlow() {
    final phone = _phone.text.trim();
    final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
    
    if (!e164.hasMatch(phone)) {
      setState(() => _err = 'Invalid phone format. Use E.164 like +22212345678');
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

    // Listener for PIN login
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

    // Listener for OTP flow - survives widget rebuild
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!mounted) return;
      if (!next.otpFlowActive) return; // Only process if OTP flow is active
      
      if (kDebugMode) {
        print('[PhonePinLogin] OTP Listener: isLoading=${next.isLoading}, error=${next.error}, phone=${next.phone}, otpFlowActive=${next.otpFlowActive}');
      }
      
      // Navigate when OTP is sent successfully
      if (!next.isLoading && next.error == null && next.phone != null) {
        if (kDebugMode) {
          print('[PhonePinLogin] ✅ OTP ready, navigating to /otp');
        }
        if (context.mounted) {
          // End OTP flow before navigation
          ref.read(authProvider.notifier).endOtpFlow();
          context.push('/otp');
        }
      }
      
      // Handle errors
      if (next.error != null && previous?.error != next.error) {
        if (kDebugMode) {
          print('[PhonePinLogin] ❌ OTP error: ${next.error}');
        }
        // Flow already ended in provider on error
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
              onPressed: authState.isLoading ? null : _continue,
              child: const Text('Continue'),
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