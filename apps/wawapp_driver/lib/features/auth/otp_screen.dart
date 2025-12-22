import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_service_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});
  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;

    if (kDebugMode) {
      print('[OtpScreen] Verifying OTP code');
    }

    await ref.read(authProvider.notifier).verifyOtp(code);

    if (!mounted) return;

    final authState = ref.read(authProvider);

    if (authState.error != null) {
      if (kDebugMode) {
        print('[OtpScreen] Verification error: ${authState.error}');
      }
      return;
    }

    if (authState.user != null) {
      if (kDebugMode) {
        print(
            '[OtpScreen] OTP verified successfully, hasPin=${authState.hasPin}');
      }

      if (!context.mounted) return;

      if (authState.hasPin) {
        if (kDebugMode) {
          print('[OtpScreen] PIN exists, going to home');
        }
        if (!context.mounted) return;
        context.go('/');
      } else {
        if (kDebugMode) {
          print('[OtpScreen] No PIN, navigating to create PIN');
        }
        if (!context.mounted) return;
        context.pushReplacement('/create-pin');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enter SMS Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                key: const Key('otpField'),
                maxLength: 6,
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Code')),
            if (authState.error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(authState.error!,
                      style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                key: const Key('verifyButton'),
                onPressed: authState.isLoading ? null : _verify,
                child: authState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify')),
          ],
        ),
      ),
    );
  }
}
