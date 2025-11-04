import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/pin_input_field.dart';

class ForgotPinScreen extends ConsumerStatefulWidget {
  const ForgotPinScreen({super.key});

  @override
  ConsumerState<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends ConsumerState<ForgotPinScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  String? _verificationId;
  int _step = 0; // 0: phone, 1: otp, 2: new pin, 3: confirm pin

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0) {
      ref.read(authNotifierProvider.notifier).sendOTP(_phoneController.text.trim());
    } else if (_step == 1 && _otpController.text.length == 6) {
      setState(() => _step = 2);
    } else if (_step == 2 && _pinController.text.length == 4) {
      setState(() => _step = 3);
    } else if (_step == 3 && _confirmPinController.text.length == 4) {
      if (_pinController.text == _confirmPinController.text) {
        ref.read(authNotifierProvider.notifier).resetPin(
          phoneNumber: _phoneController.text.trim(),
          verificationId: _verificationId!,
          otp: _otpController.text,
          newPin: _pinController.text,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          ref.listen(authStateProvider, (previous, next) {
            if (next is OTPSent) {
              setState(() {
                _verificationId = next.verificationId;
                _step = 1;
              });
            } else if (next is AuthSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN reset successfully')),
              );
              context.go('/auth/login');
            } else if (next is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(next.message)),
              );
            }
          });
          
          return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                
                Text(
                  'Reset PIN',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 48),
                
                if (_step == 0) ...[
                  PhoneInputField(controller: _phoneController),
                ] else if (_step == 1) ...[
                  OTPInputField(
                    controller: _otpController,
                    onCompleted: (_) => _nextStep(),
                  ),
                ] else if (_step == 2) ...[
                  Text('Enter new PIN', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Center(
                    child: PinInputField(
                      controller: _pinController,
                      onCompleted: (_) => _nextStep(),
                    ),
                  ),
                ] else if (_step == 3) ...[
                  Text('Confirm new PIN', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Center(
                    child: PinInputField(
                      controller: _confirmPinController,
                      onCompleted: (_) => _nextStep(),
                    ),
                  ),
                ],
                
                const Spacer(),
                
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}
