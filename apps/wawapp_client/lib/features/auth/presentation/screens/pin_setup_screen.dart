import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user_entity.dart';
import '../providers/auth_providers.dart';
import '../widgets/pin_input_field.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String otp;
  final String phoneNumber;
  
  const PinSetupScreen({
    super.key,
    required this.verificationId,
    required this.otp,
    required this.phoneNumber,
  });

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _showConfirm = false;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _onPinComplete(String pin) {
    if (!_showConfirm) {
      setState(() => _showConfirm = true);
    } else {
      if (_pinController.text == _confirmPinController.text) {
        ref.read(authNotifierProvider.notifier).verifyOTP(
          verificationId: widget.verificationId,
          otp: widget.otp,
          pin: pin,
          accountType: AccountType.client,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PINs do not match')),
        );
        setState(() {
          _showConfirm = false;
          _pinController.clear();
          _confirmPinController.clear();
        });
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
            if (next is AuthSuccess) {
              context.go('/home');
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
                  _showConfirm ? l10n.auth_pin_confirm_title : l10n.auth_pin_setup_title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  _showConfirm ? 'Re-enter your PIN' : l10n.auth_pin_setup_subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                Center(
                  child: PinInputField(
                    controller: _showConfirm ? _confirmPinController : _pinController,
                    onCompleted: _onPinComplete,
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
