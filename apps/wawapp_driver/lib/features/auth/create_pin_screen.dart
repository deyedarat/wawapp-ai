import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/phone_pin_auth.dart';

class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});
  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();
  String? _err;
  bool _busy = false;

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
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      if (kDebugMode) {
        print('[CreatePinScreen] Saving PIN');
      }
      await PhonePinAuth.instance.setPin(_p1.text);
      if (kDebugMode) {
        print('[CreatePinScreen] PIN saved, navigating to home');
      }

      if (!mounted) {
        return;
      }
      setState(() => _busy = false);

      if (!context.mounted) {
        return;
      }
      Navigator.popUntil(context, (r) => r.isFirst);
    } on Object catch (e, st) {
      if (kDebugMode) {
        print('[CreatePinScreen] Error: $e\n$st');
      }
      if (!mounted) {
        return;
      }
      setState(() => _err = 'Failed to save PIN. Please try again.');
    } finally {
      // _busy already set to false in try block
    }
  }

  @override
  Widget build(BuildContext context) {
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
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: _busy ? null : _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
