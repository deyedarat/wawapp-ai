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
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear any pre-filled text
    _codeController.clear();

    // Reset loading state when OTP screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(authProvider);
      if (currentState.isLoading) {
        // Force reset loading state if stuck
        ref.read(authProvider.notifier).state = currentState.copyWith(isLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    
    // Test OTP bypass for development
    if (code == '123456') {
      // Simulate successful verification
      context.go('/create-pin');
      return;
    }
    
    await ref.read(authProvider.notifier).verifyOtp(code);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (prev, next) {
      if (next.user != null && !next.isLoading) {
        context.go('/create-pin');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Enter OTP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter the 6-digit code sent to ${authState.phoneE164}'),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'OTP Code'),
            ),
            if (authState.error != null)
              Text(authState.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: authState.isLoading ? null : _verify,
              child: authState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
