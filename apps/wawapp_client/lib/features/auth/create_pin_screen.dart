import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'providers/auth_service_provider.dart';

class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});

  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4) return;
    if (pin != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs do not match')),
      );
      return;
    }

    await ref.read(authProvider.notifier).createPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isEnforced = authState.user != null && !authState.hasPin;

    // Navigation is now handled by GoRouter's redirect function
    ref.listen(authProvider, (prev, next) {
      debugPrint(
        '[CreatePinScreen] Auth state changed - '
        'hasPin=${next.hasPin} '
        'isLoading=${next.isLoading}'
      );

      // Log PIN creation success for debugging
      if (next.hasPin && !prev!.hasPin) {
        FirebaseCrashlytics.instance.log('[CreatePinScreen] PIN created successfully');
        debugPrint('[CreatePinScreen] ✓ PIN created - GoRouter will handle navigation');
      }
    });

    return PopScope(
      canPop: !isEnforced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create PIN'),
          automaticallyImplyLeading: !isEnforced,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Create a 4-digit PIN for quick login'),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm PIN'),
              ),
              if (authState.error != null)
                Text(authState.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _createPin,
                child: authState.isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
