import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'providers/auth_service_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  /// Phone number to send OTP to (used for phone change flow)
  final String? phoneNumber;

  /// Flag to indicate this is a phone change verification (not login)
  /// Bug #5 FIX: Add support for phone change verification flow
  final bool isPhoneChange;

  const OtpScreen({
    super.key,
    this.phoneNumber,
    this.isPhoneChange = false,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Clear any pre-filled text
    _codeController.clear();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;

    // Bug #5 FIX: Different behavior for phone change vs login
    if (widget.isPhoneChange) {
      // Phone change flow: just verify OTP and return success
      try {
        await ref.read(authProvider.notifier).verifyOtp(code);
        if (mounted) {
          // Return true to indicate verification success
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        // Error will be shown via authState.error in the UI
        debugPrint('[OtpScreen] Phone verification failed: $e');
      }
    } else {
      // Login flow: Navigation will be handled automatically by GoRouter
      await ref.read(authProvider.notifier).verifyOtp(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Navigation is now handled by GoRouter's redirect function
    // No need for manual navigation listeners
    ref.listen(authProvider, (prev, next) {
      debugPrint('[OtpScreen] Auth state changed - '
          'user=${next.user?.uid ?? 'null'} '
          'hasPin=${next.hasPin} '
          'isLoading=${next.isLoading} '
          'otpStage=${next.otpStage}');

      // Log OTP verification success for debugging
      if (next.user != null && prev?.user == null) {
        FirebaseCrashlytics.instance
            .log('[OtpScreen] OTP verified successfully');
        debugPrint(
            '[OtpScreen] ✓ OTP verified - GoRouter will handle navigation');
      }
    });

    // Bug #5 FIX: Display phone from widget param if provided (phone change flow)
    final displayPhone = widget.phoneNumber ?? authState.phoneE164;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isPhoneChange ? 'تحقق من الهاتف' : 'أدخل رمز التحقق'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              widget.isPhoneChange
                  ? 'أدخل الرمز المكون من 6 أرقام المرسل إلى $displayPhone'
                  : 'Enter the 6-digit code sent to $displayPhone',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'OTP Code'),
            ),
            if (authState.error != null)
              Text(authState.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: authState.isLoading ? null : _verify,
              child: authState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
