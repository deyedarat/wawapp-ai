import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/providers/auth_service_provider.dart';
import '../../theme/colors.dart';
import '../../theme/components.dart';

/// Screen for changing user's PIN
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authProvider.notifier);
      final currentPin = _currentPinController.text;
      final newPin = _newPinController.text;

      // Verify current PIN first
      final isValid = await authService.verifyCurrentPin(currentPin);
      if (!isValid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رمز PIN الحالي غير صحيح'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Set new PIN
      await authService.setPin(newPin);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تغيير رمز PIN بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      context.pop();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تغيير رمز PIN'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.all(WawAppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info Card
                WawCard(
                  elevation: WawAppElevation.low,
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: WawAppSpacing.md),
                      Expanded(
                        child: Text(
                          'رمز PIN يستخدم لتسجيل الدخول السريع. يجب أن يكون 4 أرقام.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: WawAppSpacing.lg),

                // Current PIN Field
                TextFormField(
                  controller: _currentPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: _obscureCurrentPin,
                  decoration: InputDecoration(
                    labelText: 'رمز PIN الحالي',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCurrentPin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureCurrentPin = !_obscureCurrentPin);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رمز PIN الحالي';
                    }
                    if (value.length != 4) {
                      return 'رمز PIN يجب أن يكون 4 أرقام';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                      return 'رمز PIN يجب أن يحتوي على أرقام فقط';
                    }
                    return null;
                  },
                ),

                SizedBox(height: WawAppSpacing.md),

                // New PIN Field
                TextFormField(
                  controller: _newPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: _obscureNewPin,
                  decoration: InputDecoration(
                    labelText: 'رمز PIN الجديد',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureNewPin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() => _obscureNewPin = !_obscureNewPin);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال رمز PIN الجديد';
                    }
                    if (value.length != 4) {
                      return 'رمز PIN يجب أن يكون 4 أرقام';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value)) {
                      return 'رمز PIN يجب أن يحتوي على أرقام فقط';
                    }
                    if (value == _currentPinController.text) {
                      return 'رمز PIN الجديد يجب أن يكون مختلفاً عن الحالي';
                    }
                    return null;
                  },
                ),

                SizedBox(height: WawAppSpacing.md),

                // Confirm PIN Field
                TextFormField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: _obscureConfirmPin,
                  decoration: InputDecoration(
                    labelText: 'تأكيد رمز PIN الجديد',
                    hintText: '••••',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPin = !_obscureConfirmPin);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء تأكيد رمز PIN الجديد';
                    }
                    if (value != _newPinController.text) {
                      return 'رمز PIN غير متطابق';
                    }
                    return null;
                  },
                ),

                SizedBox(height: WawAppSpacing.xl),

                // Change PIN Button
                WawActionButton(
                  label: 'تغيير رمز PIN',
                  icon: Icons.check,
                  onPressed: _isLoading ? null : _changePin,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
