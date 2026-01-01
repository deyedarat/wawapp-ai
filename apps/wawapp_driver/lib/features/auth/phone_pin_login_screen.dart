import 'package:auth_shared/auth_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'providers/auth_service_provider.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() => _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _phone.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final pin = _pin.text.trim();
    if (pin.isEmpty) {
      setState(() => _err = 'يرجى إدخال الرمز السري');
      return;
    }

    // Get and normalize phone
    String phone = _phone.text.trim();

    // Validate and convert to E.164 format for Mauritania
    try {
      if (phone.startsWith('+')) {
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() => _err = 'رقم هاتف غير صحيح بصيغة +222');
          return;
        }
      } else {
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() => _err = MauritaniaPhoneUtils.getValidationError(phone));
          return;
        }
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      }
    } catch (e) {
      setState(() => _err = 'رقم هاتف غير صحيح');
      return;
    }

    setState(() => _err = null);

    // Pass normalized phone to loginByPin
    await ref.read(authProvider.notifier).loginByPin(pin, phone);
  }

  Future<void> _handleForgotPin() async {
    String phone = _phone.text.trim();

    // Validate and convert to E.164 format for Mauritania
    try {
      if (phone.startsWith('+')) {
        // Already in E.164, validate it
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() => _err = 'رقم هاتف غير صحيح بصيغة +222');
          return;
        }
      } else {
        // Local format, validate and convert
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() => _err = MauritaniaPhoneUtils.getValidationError(phone));
          return;
        }
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
        // Update text field with E.164 format
        _phone.text = phone;
      }
    } catch (e) {
      setState(() => _err = 'رقم هاتف غير صحيح');
      return;
    }

    setState(() => _err = null);

    // Check if phone exists before sending OTP
    final phoneExists = await ref.read(authProvider.notifier).checkPhoneExists(phone);
    if (!phoneExists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رقم الهاتف غير مسجل. يرجى التسجيل أولاً'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      print('[PhonePinLogin] Starting PIN reset flow for phone: $phone');
    }

    // Start PIN reset flow - sends OTP
    ref.read(authProvider.notifier).startPinResetFlow();

    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (kDebugMode) {
        print('[PhonePinLogin] OTP sent for PIN reset');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[PhonePinLogin] OTP send failed: ${e.runtimeType} - $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال OTP: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleNewDeviceRegistration() async {
    String phone = _phone.text.trim();

    // Validate and convert to E.164 format for Mauritania
    try {
      if (phone.startsWith('+')) {
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() => _err = 'رقم هاتف غير صحيح بصيغة +222');
          return;
        }
      } else {
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() => _err = MauritaniaPhoneUtils.getValidationError(phone));
          return;
        }
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
        _phone.text = phone;
      }
    } on Exception {
      setState(() => _err = 'رقم هاتف غير صحيح');
      return;
    }

    setState(() => _err = null);

    if (kDebugMode) {
      print('[PhonePinLogin] Starting registration flow for phone: $phone');
    }

    // Mark OTP flow as active for new registration
    ref.read(authProvider.notifier).startOtpFlow();

    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      if (kDebugMode) {
        print('[PhonePinLogin] OTP sent for new registration');
      }
    } on Object catch (e) {
      if (kDebugMode) {
        print('[PhonePinLogin] OTP send failed: ${e.runtimeType} - $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال OTP: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final errorMessage = _err ?? authState.error;

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sign_in_with_phone)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('phoneField'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (8 أرقام)',
                helperText: 'مثال: 22123456 أو +22222123456',
                errorText: _err,
                prefixText: _phone.text.startsWith('+') ? '' : '+222 ',
              ),
              onChanged: (_) => setState(() => _err = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.pin_label),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const Key('loginButton'),
              onPressed: authState.isLoading ? null : _handleLogin,
              child: authState.isLoading ? const CircularProgressIndicator() : const Text('تسجيل الدخول'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: authState.isLoading ? null : _handleForgotPin,
              child: const Text(
                'نسيت الرمز السري؟',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: authState.isLoading ? null : _handleNewDeviceRegistration,
              child: const Text('جهاز جديد أو تسجيل لأول مرة؟ التحقق عبر SMS'),
            ),
          ],
        ),
      ),
    );
  }
}
