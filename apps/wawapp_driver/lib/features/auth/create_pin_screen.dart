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

  Future<void> _save() async {
    if (_p1.text.length != 4 || _p2.text.length != 4 || _p1.text != _p2.text) {
      setState(() => _err = 'Enter 4 digits and confirm');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await PhonePinAuth.instance.setPin(_p1.text);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
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
