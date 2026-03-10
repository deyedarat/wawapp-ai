import 'dart:async';

import 'package:auth_shared/auth_shared.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/fcm_service.dart';
import '../../services/log_service.dart';
import 'bug_report_screen.dart';
import 'providers/auth_service_provider.dart';

class PhonePinLoginScreen extends ConsumerStatefulWidget {
  const PhonePinLoginScreen({super.key});
  @override
  ConsumerState<PhonePinLoginScreen> createState() => _PhonePinLoginScreenState();
}

class _PhonePinLoginScreenState extends ConsumerState<PhonePinLoginScreen> with WidgetsBindingObserver {
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _isNewUser = false;
  bool _checkingPhone = false;
  String? _phoneError;
  bool _navigationInProgress = false;

  // Cooldown + double-tap protection
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  bool _isRequesting = false;
  // Prevents showing the bug report dialog twice if widget rebuilds after error
  bool _bugReportShownForCurrentError = false;

  // Prevents navigating to OTP screen more than once per attempt
  bool _navigatedThisAttempt = false;

  // Tracks whether we are waiting for the user to return from reCAPTCHA
  bool _waitingForCaptchaReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _phone.dispose();
    _pin.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Called when the app lifecycle changes (e.g. returning from reCAPTCHA WebView).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _waitingForCaptchaReturn) {
      debugPrint('[LoginScreen] App resumed after reCAPTCHA – checking OTP stage');
      _waitingForCaptchaReturn = false;

      // Give Firebase 500 ms to process the CAPTCHA result, then check state
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final authState = ref.read(authProvider);
        debugPrint('[LoginScreen] Post-CAPTCHA resume: otpStage=${authState.otpStage}');
        if (authState.otpStage == OtpStage.codeSent && !_navigatedThisAttempt) {
          _navigatedThisAttempt = true;
          debugPrint('[LoginScreen] ✓ codeSent confirmed after resume – GoRouter will redirect to /otp');
        }
      });
    }
  }

  /// Starts the 60-second cooldown immediately when the button is tapped.
  /// Fires regardless of whether the OTP request succeeds or fails.
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownRemaining--;
        if (_cooldownRemaining <= 0) {
          timer.cancel();
          _cooldownRemaining = 0;
        }
      });
    });
  }

  /// Shows a dialog asking the user if they want to send a bug report.
  /// Triggered on Firebase unknown errors (including Error code:39).
  void _showBugReportDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حدث خطأ أثناء التحقق'),
          content: const Text(
            'حدث خطأ أثناء التحقق من رقم الهاتف. '
            'هل تريد إرسال تقرير لمساعدتنا في حل المشكلة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BugReportScreen()),
                );
              },
              child: const Text('إرسال تقرير'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkPhone() async {
    final phone = _phone.text.trim();

    // Validate and convert to E.164 format
    String phoneE164;
    try {
      if (phone.startsWith('+')) {
        // Already in E.164, validate it
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() {
            _phoneError = 'رقم هاتف غير صحيح بصيغة +222';
          });
          return;
        }
        phoneE164 = phone;
      } else {
        // Local format, validate and convert
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() {
            _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
          });
          return;
        }
        phoneE164 = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      }
    } catch (e) {
      setState(() {
        _phoneError = 'رقم هاتف غير صحيح';
      });
      return;
    }

    setState(() {
      _checkingPhone = true;
      _phoneError = null;
    });

    final exists = await ref.read(authProvider.notifier).checkPhoneExists(phoneE164);
    setState(() {
      _checkingPhone = false;
      _isNewUser = !exists;
      // Update the text field with E.164 format for clarity
      _phone.text = phoneE164;
    });
  }

  Future<void> _loginWithPin() async {
    if (_pin.text.length != 4) return;

    String phone = _phone.text.trim();

    // Ensure phone is in E.164 format
    if (!phone.startsWith('+')) {
      try {
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      } catch (e) {
        setState(() {
          _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
        });
        return;
      }
    }

    await ref.read(authProvider.notifier).loginByPin(_pin.text, phone);
  }

  Future<void> _createAccount() async {
    // Double-tap guard + cooldown guard
    if (_isRequesting || _cooldownRemaining > 0) return;

    String phone = _phone.text.trim();

    // Ensure phone is in E.164 format
    if (!phone.startsWith('+')) {
      try {
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
      } catch (e) {
        setState(() {
          _phoneError = MauritaniaPhoneUtils.getValidationError(phone);
        });
        return;
      }
    }

    debugPrint('[LoginScreen] _createAccount() called for phone=${LogService.instance.maskPhone(phone)}');

    // Reset per-attempt navigation guard
    _navigatedThisAttempt = false;
    _waitingForCaptchaReturn = true; // reCAPTCHA WebView is about to open

    // Start cooldown immediately on tap (before Firebase responds)
    _startCooldown();
    _isRequesting = true;
    _bugReportShownForCurrentError = false; // reset for this new attempt

    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      debugPrint('[LoginScreen] sendOtp() returned successfully');

      // Use shouldOfferBugReport typed flag (not string-matching) to trigger dialog.
      // Guard with _bugReportShownForCurrentError prevents double-fire on rebuild.
      if (mounted && ref.read(authProvider).shouldOfferBugReport && !_bugReportShownForCurrentError) {
        _bugReportShownForCurrentError = true;
        _showBugReportDialog(context);
      }
    } catch (e, stackTrace) {
      debugPrint('[LoginScreen] sendOtp() threw: ${e.runtimeType}');
      _waitingForCaptchaReturn = false; // reCAPTCHA failed, not waiting anymore
      LogService.instance.addLog(
        event: 'otp_create_account_exception',
        errorCode: 'exception',
        errorMessage: e.runtimeType.toString(),
      );
      FirebaseCrashlytics.instance.recordError(e, stackTrace, fatal: false, printDetails: false);
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  Future<void> _handleForgotPin() async {
    // Double-tap guard + cooldown guard
    if (_isRequesting || _cooldownRemaining > 0) return;

    String phone = _phone.text.trim();

    // Validate and convert to E.164 format for Mauritania
    try {
      if (phone.startsWith('+')) {
        if (!MauritaniaPhoneUtils.isValidMauritaniaE164(phone)) {
          setState(() => _phoneError = 'رقم هاتف غير صحيح بصيغة +222');
          return;
        }
      } else {
        if (!MauritaniaPhoneUtils.isValidMauritaniaLocalNumber(phone)) {
          setState(() => _phoneError = MauritaniaPhoneUtils.getValidationError(phone));
          return;
        }
        phone = MauritaniaPhoneUtils.toMauritaniaE164(phone);
        _phone.text = phone;
      }
    } catch (e) {
      setState(() => _phoneError = 'رقم هاتف غير صحيح');
      return;
    }

    setState(() => _phoneError = null);
    debugPrint('[LoginScreen] Starting PIN reset flow for phone: ${LogService.instance.maskPhone(phone)}');

    // Reset per-attempt navigation guard
    _navigatedThisAttempt = false;
    _waitingForCaptchaReturn = true; // reCAPTCHA WebView is about to open

    // Start cooldown immediately on tap
    _startCooldown();
    _isRequesting = true;
    _bugReportShownForCurrentError = false; // reset for this new attempt

    ref.read(authProvider.notifier).startPinResetFlow();

    try {
      await ref.read(authProvider.notifier).sendOtp(phone);
      debugPrint('[LoginScreen] OTP sent for PIN reset');

      if (mounted && ref.read(authProvider).shouldOfferBugReport && !_bugReportShownForCurrentError) {
        _bugReportShownForCurrentError = true;
        _showBugReportDialog(context);
      }
    } on Object catch (e) {
      debugPrint('[LoginScreen] OTP send failed: ${e.runtimeType}');
      _waitingForCaptchaReturn = false;
      // Error message already translated and stored in authState.error by the notifier
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Navigation is now handled by GoRouter's redirect function
    ref.listen(authProvider, (prev, next) {
      debugPrint('[LoginScreen] Auth state changed: '
          'otpStage=${next.otpStage}, '
          'otpFlowActive=${next.otpFlowActive}, '
          'user=${next.user?.uid ?? 'null'}, '
          'error=${next.error}');

      // OTP code sent: add 800ms delay before letting GoRouter redirect to /otp
      // This prevents the about:blank race condition when returning from reCAPTCHA
      // IMPROVED FIX: Increased delay for slow devices and to ensure WebView fully closes
      if (next.otpStage == OtpStage.codeSent && prev?.otpStage != OtpStage.codeSent && !_navigatedThisAttempt) {
        _navigatedThisAttempt = true;
        _waitingForCaptchaReturn = false;
        debugPrint('[LoginScreen] ✓ OTP codeSent – waiting 800ms for WebView to close before GoRouter redirect');
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            debugPrint('[LoginScreen] ✓ 800ms delay done – GoRouter will redirect to /otp');
            // Force a state refresh so GoRouter re-evaluates the redirect
            setState(() {});
          }
        });
      }

      // Initialize services when user logs in successfully
      if (next.user != null && prev?.user == null && !_navigationInProgress) {
        _navigationInProgress = true;

        debugPrint('[LoginScreen] ✓ User authenticated - initializing services');

        // Crashlytics breadcrumb
        FirebaseCrashlytics.instance.log('[LoginScreen] PIN login successful');

        // Schedule side-effects after current frame to avoid build-phase mutations
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Set basic user properties immediately after auth
            AnalyticsService.instance.setUserProperties(userId: next.user!.uid);
            AnalyticsService.instance.logAuthCompleted(method: 'phone_pin');

            // Initialize FCM for push notifications
            FCMService.instance.initialize(context);

            debugPrint('[LoginScreen] Services initialized - GoRouter will handle navigation');
          }
        });
      }
    });

    final l10n = AppLocalizations.of(context)!;
    // Cooldown + requesting guard for the verify button
    final bool canRequest = !_isRequesting && _cooldownRemaining == 0;

    return Scaffold(
      key: const Key('login_screen'),
      appBar: AppBar(title: Text(l10n.sign_in)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (8 أرقام)',
                helperText: 'مثال: 22123456 أو +22222123456',
                errorText: _phoneError,
                prefixText: _phone.text.startsWith('+') ? '' : '+222 ',
              ),
              onChanged: (_) => setState(() {
                _isNewUser = false;
                _phoneError = null;
              }),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _checkingPhone ? null : _checkPhone,
              child: _checkingPhone ? const CircularProgressIndicator() : Text(l10n.check_phone),
            ),
            const SizedBox(height: 16),
            if (_isNewUser) ...[
              Text(l10n.new_user_create_account),
              const SizedBox(height: 8),
              // Countdown label (shown during cooldown)
              if (_cooldownRemaining > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'يمكنك إعادة المحاولة بعد $_cooldownRemaining ثانية',
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ElevatedButton(
                // Disabled during cooldown or active request
                onPressed: (authState.isLoading || !canRequest) ? null : _createAccount,
                child: Text(l10n.create_account),
              ),
            ] else if (!_isNewUser && _phone.text.isNotEmpty) ...[
              Text(l10n.existing_user_enter_pin),
              TextField(
                controller: _pin,
                maxLength: 4,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.pin_label),
              ),
              ElevatedButton(
                onPressed: authState.isLoading ? null : _loginWithPin,
                child: Text(l10n.login),
              ),
              const SizedBox(height: 8),
              // Countdown label for forgot-pin cooldown
              if (_cooldownRemaining > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'يمكنك إعادة المحاولة بعد $_cooldownRemaining ثانية',
                    style: const TextStyle(color: Colors.orange, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextButton(
                onPressed: (authState.isLoading || !canRequest) ? null : _handleForgotPin,
                child: const Text(
                  'نسيت الرمز السري؟',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            // Error message (always user-friendly Arabic, never raw exception)
            if (authState.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  authState.error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
