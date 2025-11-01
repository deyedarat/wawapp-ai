import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/phone_pin_auth.dart';
import 'otp_screen.dart';

class PhonePinLoginScreen extends StatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  State<PhonePinLoginScreen> createState() => _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends State<PhonePinLoginScreen> {
  final _phone = TextEditingController(); // e.g. +222xxxxxxxx
  final _pin = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final phone = _phone.text.trim();
      if (!phone.startsWith('+')) {
        setState(() => _err = 'Use E.164 like +222...');
        return;
      }

      await PhonePinAuth.instance.ensurePhoneSession(phone);

      if (FirebaseAuth.instance.currentUser == null) {
        if (mounted)
          Navigator.push(
              context, MaterialPageRoute(builder: (_) => const OtpScreen()));
        return;
      }

      if (_pin.text.length != 4) {
        setState(() => _err = 'PIN must be 4 digits');
        return;
      }
      final ok = await PhonePinAuth.instance.verifyPin(_pin.text);
      if (!ok) {
        setState(() => _err = 'Invalid PIN');
        return;
      }

      if (mounted) Navigator.pop(context); // success
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration:
                    const InputDecoration(labelText: 'Phone (+222...)')),
            const SizedBox(height: 12),
            TextField(
                controller: _pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PIN (4 digits)')),
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: _busy ? null : _continue,
                child: const Text('Continue')),
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      await PhonePinAuth.instance
                          .ensurePhoneSession(_phone.text.trim());
                      if (mounted)
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OtpScreen()));
                    },
              child: const Text('New device or forgot PIN? Verify by SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
