import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/phone_pin_auth.dart';
import 'create_pin_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  String? _err;
  bool _busy = false;

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await PhonePinAuth.instance.confirmOtp(_code.text.trim());
      if (kDebugMode) {
        print('[OtpScreen] OTP verified, checking for existing PIN');
      }

      final hasPin = await PhonePinAuth.instance.hasPinHash();
      if (kDebugMode) {
        print('[OtpScreen] hasPin=$hasPin');
      }

      if (!mounted) {
        return;
      }
      setState(() => _busy = false);

      if (!context.mounted) {
        return;
      }

      if (hasPin) {
        if (kDebugMode) {
          print('[OtpScreen] PIN exists, navigating to home');
        }
        Navigator.popUntil(context, (r) => r.isFirst);
      } else {
        if (kDebugMode) {
          print('[OtpScreen] No PIN, navigating to create PIN');
        }
        await Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const CreatePinScreen()));
      }
    } on Object catch (e, st) {
      if (kDebugMode) {
        print('[OtpScreen] Error: $e\n$st');
      }
      if (!mounted) {
        return;
      }
      setState(() => _err = 'Invalid code. Please try again.');
    } finally {
      // _busy already set to false in try block
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter SMS Code')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
                maxLength: 6,
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Code')),
            if (_err != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      Text(_err!, style: const TextStyle(color: Colors.red))),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: _busy ? null : _verify, child: const Text('Verify')),
          ],
        ),
      ),
    );
  }
}
