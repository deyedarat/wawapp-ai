import 'package:flutter/foundation.dart';
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

  bool _isValidPin(String pin) {
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }
    if (pin.split('').every((d) => d == pin[0])) {
      return false;
    }
    const seq = {'0123', '1234', '2345', '3456', '4567', '5678', '6789'};
    const rseq = {'3210', '4321', '5432', '6543', '7654', '8765', '9876'};
    if (seq.contains(pin) || rseq.contains(pin)) {
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (_p1.text.length != 4) {
      setState(() => _err = 'PIN must be 4 digits');
      return;
    }
    if (!_isValidPin(_p1.text)) {
      setState(
          () => _err = 'PIN too weak. Avoid sequences or repeated digits.');
      return;
    }
    if (_p1.text != _p2.text) {
      setState(() => _err = 'PINs do not match');
      return;
    }
    setState(() => _err = null);

    if (kDebugMode) {
      print('[CreatePinScreen] Saving PIN');
    }

    await ref.read(authProvider.notifier).createPin(_p1.text);

    if (kDebugMode) {
      print('[CreatePinScreen] createPin call completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for PIN creation status
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.hasPin && !next.isLoading) {
        if (kDebugMode) {
          print('[CreatePinScreen] PIN saved');
        }
      }
      if (next.error != null && previous?.error != next.error) {
        if (kDebugMode) {
          print('[CreatePinScreen] Error: ${next.error}');
        }
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
