import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_service_provider.dart';
import 'package:auth_shared/auth_shared.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() =>
      _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _isNewUser = false;
  bool _checkingPhone = false;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _checkPhone() async {
    final phone = _phone.text.trim();
    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use E.164 format like +222...')),
      );
      return;
    }

    setState(() => _checkingPhone = true);
    final exists = await ref.read(authProvider.notifier).checkPhoneExists(phone);
    setState(() {
      _checkingPhone = false;
      _isNewUser = !exists;
    });
  }

  Future<void> _loginWithPin() async {
    if (_pin.text.length != 4) return;
    await ref.read(authProvider.notifier).loginByPin(_pin.text);
  }

  Future<void> _createAccount() async {
    await ref.read(authProvider.notifier).sendOtp(_phone.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.otpStage == OtpStage.codeSent) {
        context.go('/otp');
      }
      if (next.user != null && next.hasPin && !next.isLoading) {
        context.go('/');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (+222...)'),
              onChanged: (_) => setState(() => _isNewUser = false),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkingPhone ? null : _checkPhone,
              child: _checkingPhone
                  ? const CircularProgressIndicator()
                  : const Text('Check Phone'),
            ),
            const SizedBox(height: 16),
            if (_isNewUser) ..[
              const Text('New user - Create account'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _createAccount,
                child: const Text('Create Account'),
              ),
            ] else if (!_isNewUser && _phone.text.isNotEmpty) ..[
              const Text('Existing user - Enter PIN'),
              TextField(
                controller: _pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _loginWithPin,
                child: const Text('Login'),
              ),
            ],
            if (authState.error != null)
              Text(authState.error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
