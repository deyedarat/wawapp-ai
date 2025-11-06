import 'package:flutter/foundation.dart';
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
      final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
      if (!e164.hasMatch(phone)) {
        setState(
            () => _err = 'Invalid phone format. Use E.164 like +22212345678');
        return;
      }

      if (kDebugMode) {
        print('[PhonePinLogin] Attempting login');
      }

      await PhonePinAuth.instance.ensurePhoneSession(phone);

      if (FirebaseAuth.instance.currentUser == null) {
        if (kDebugMode) {
          print('[PhonePinLogin] Not signed in, navigating to OTP');
        }

        if (!mounted) {
          return;
        }
        setState(() => _busy = false);

        if (!context.mounted) {
          return;
        }
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const OtpScreen()));
        return;
      }

      if (_pin.text.length != 4) {
        setState(() => _err = 'PIN must be 4 digits');
        return;
      }

      if (kDebugMode) {
        print('[PhonePinLogin] Verifying PIN');
      }
      final ok = await PhonePinAuth.instance.verifyPin(_pin.text);
      if (!ok) {
        if (kDebugMode) {
          print('[PhonePinLogin] PIN verification failed');
        }
        setState(() => _err = 'Invalid PIN. Please try again.');
        return;
      }

      if (kDebugMode) {
        print('[PhonePinLogin] Login success');
      }

      if (!mounted) {
        return;
      }
      setState(() => _busy = false);

      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
    } on Object catch (e, st) {
      if (kDebugMode) {
        print('[PhonePinLogin] Error: $e\n$st');
      }
      if (!mounted) {
        return;
      }
      setState(() => _err = 'Login failed. Please check your connection.');
    } finally {
      // _busy already set to false in try block
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
                      final phone = _phone.text.trim();
                      final e164 = RegExp(r'^\+[1-9]\d{6,14}$');
                      if (!e164.hasMatch(phone)) {
                        setState(() => _err =
                            'Invalid phone format. Use E.164 like +22212345678');
                        return;
                      }
                      setState(() {
                        _busy = true;
                        _err = null;
                      });
                      try {
                        if (kDebugMode) {
                          print('[PhonePinLogin] SMS verification requested');
                        }
                        await PhonePinAuth.instance.ensurePhoneSession(phone);

                        if (!mounted) {
                          return;
                        }
                        setState(() => _busy = false);

                        if (!context.mounted) {
                          return;
                        }
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const OtpScreen()));
                      } on Object catch (e, st) {
                        if (kDebugMode) {
                          print('[PhonePinLogin] SMS error: $e\n$st');
                        }
                        if (!mounted) {
                          return;
                        }
                        setState(() => _err = 'Failed to send SMS. Try again.');
                      } finally {
                        // _busy already set to false in try block
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
