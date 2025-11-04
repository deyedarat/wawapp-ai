import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_providers.dart';
import '../widgets/phone_input_field.dart';
import '../widgets/pin_input_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authNotifierProvider.notifier).loginWithPin(
        phoneNumber: _phoneController.text.trim(),
        pin: _pinController.text,
      );
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
            } else if (next is AccountLocked) {
              final minutes = next.lockoutDuration.inMinutes;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.auth_error_account_locked.replaceAll(
                    '{duration}',
                    '$minutes minutes',
                  )),
                ),
              );
            }
          });
          
          return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  
                  Text(
                    'Welcome Back',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Login to continue',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  PhoneInputField(controller: _phoneController),
                  
                  const SizedBox(height: 24),
                  
                  Text(
                    l10n.auth_pin_login_title,
                    style: theme.textTheme.titleMedium,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Center(
                    child: PinInputField(
                      controller: _pinController,
                      onCompleted: (_) => _login(),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/auth/forgot-pin'),
                      child: Text(l10n.auth_forgot_pin),
                    ),
                  ),
                  
                  const Spacer(),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final authState = ref.watch(authStateProvider);
                      final isLoading = authState is AuthLoading;
                      
                      return SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Login'),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
