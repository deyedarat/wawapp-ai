import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/providers/auth_providers.dart';
import 'otp_screen.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() => _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();

  Future<void> _continue() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use E.164 format like +222...')),
      );
      return;
    }

    final authNotifier = ref.read(authProvider.notifier);
    final authState = ref.read(authProvider);

    if (!authState.isAuthenticated) {
      await authNotifier.sendOTP(phone);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OtpScreen()),
        );
      }
      return;
    }

    if (_pin.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN must be 4 digits')),
      );
      return;
    }

    await authNotifier.loginWithPin(
      phoneNumber: phone,
      pin: _pin.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
        ref.read(authProvider.notifier).clearError();
      }
      if (next.isLocked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account locked for ${next.lockoutDuration!.inMinutes} minutes'),
          ),
        );
        ref.read(authProvider.notifier).clearLockout();
      }
    });

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
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: authState.isLoading ? null : _continue,
              child: authState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Continue'),
            ),
            TextButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      final phone = _phone.text.trim();
                      if (phone.startsWith('+')) {
                        await ref.read(authProvider.notifier).sendOTP(phone);
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OtpScreen()),
                          );
                        }
                      }
                    },
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
