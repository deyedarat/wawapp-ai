import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_service_provider.dart';

class CreatePinScreen extends ConsumerStatefulWidget {
  const CreatePinScreen({super.key});
  @override
  ConsumerState<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends ConsumerState<CreatePinScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _err;

  Future<void> _save() async {
    if (_p1.text.length != 4 || _p2.text.length != 4 || _p1.text != _p2.text) {
      setState(() => _err = 'Enter 4 digits and confirm');
      return;
    }
    setState(() => _err = null);

    await ref.read(authProvider.notifier).createPin(_p1.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for successful PIN creation and navigate
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.hasPin && !next.isLoading) {
        Navigator.popUntil(context, (r) => r.isFirst);
      }
    });

    final errorMessage = _err ?? authState.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Set PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                maxLength: 4,
                controller: _p1,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN')),
            TextField(
                maxLength: 4,
                controller: _p2,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm PIN')),
            if (errorMessage != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(errorMessage,
                      style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: authState.isLoading ? null : _save,
                child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
