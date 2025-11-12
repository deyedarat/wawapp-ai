import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_service_provider.dart';
import 'create_pin_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phone;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
    this.resendToken,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();

  Future<void> _verify() async {
    await ref.read(authProvider.notifier).verifyOtp(_code.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for successful verification
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.user != null && !next.otpFlowActive && !next.isLoading) {
        if (!context.mounted) return;
        // User authenticated, navigate to create PIN
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CreatePinScreen()),
          );
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Enter SMS Code sent to ${widget.phone}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
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
                onPressed: authState.isLoading ? null : _verify,
                child: const Text('Verify')),
          ],
        ),
      ),
    );
  }
}
