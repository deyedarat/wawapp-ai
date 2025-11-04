import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/auth_providers.dart';
import '../widgets/otp_input_field.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phoneNumber;
  
  const OTPVerificationScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _canResend = false;
  int _resendCountdown = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendCountdown = 30;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() {
          _resendCountdown--;
        });
        return _resendCountdown > 0;
      }
      return false;
    }).then((_) {
      if (mounted) {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _verifyOTP() {
    if (_otpController.text.length == 6) {
      context.push('/auth/pin-setup', extra: {
        'verificationId': widget.verificationId,
        'otp': _otpController.text,
        'phoneNumber': widget.phoneNumber,
      });
    }
  }

  void _resendOTP() {
    if (_canResend) {
      ref.read(authNotifierProvider.notifier).sendOTP(widget.phoneNumber);
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasVerificationId && previous?.verificationId != next.verificationId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New verification code sent'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(authNotifierProvider.notifier).clearError();
      }
    });
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              
              Text(
                l10n.auth_otp_title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                l10n.auth_otp_subtitle.replaceAll('{phoneNumber}', widget.phoneNumber),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 48),
              
              OTPInputField(
                controller: _otpController,
                onCompleted: (_) => _verifyOTP(),
              ),
              
              const SizedBox(height: 32),
              
              Center(
                child: TextButton(
                  onPressed: _canResend ? _resendOTP : null,
                  child: Text(
                    _canResend 
                        ? l10n.auth_otp_resend
                        : 'Resend code in ${_resendCountdown}s',
                    style: TextStyle(
                      color: _canResend 
                          ? theme.primaryColor 
                          : theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _otpController.text.length == 6 ? _verifyOTP : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n.auth_otp_verify,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
