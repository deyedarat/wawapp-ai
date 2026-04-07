import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../theme/app_theme.dart';

class MerchantLoginScreen extends StatefulWidget {
  const MerchantLoginScreen({super.key});

  @override
  State<MerchantLoginScreen> createState() => _MerchantLoginScreenState();
}

class _MerchantLoginScreenState extends State<MerchantLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'merchant@baqalati.mr');
  final _passwordController = TextEditingController(text: 'password');
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.loginAsMerchant(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authProvider = context.watch<AuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),

                // Language Toggle
                Align(
                  alignment: localeProvider.isArabic
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => localeProvider.toggleLocale(),
                    icon: const Icon(Icons.language, size: 20),
                    label: Text(
                      localeProvider.isArabic ? 'Français' : 'العربية',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Logo
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreenDark,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreenDark.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.store,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  l10n.tr('app_name_merchant'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreenDark,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  l10n.tr('merchant_dashboard'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),

                const SizedBox(height: 48),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.tr('email'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return l10n.tr('email');
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l10n.tr('password'),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return l10n.tr('password');
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Login Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreenDark,
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            l10n.tr('login'),
                            style: const TextStyle(fontSize: 18),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Info Text
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.info.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localeProvider.isArabic
                              ? 'هذه اللوحة مخصصة لأصحاب البقالات فقط. للتسجيل كتاجر، تواصل مع الإدارة.'
                              : 'Ce panneau est réservé aux propriétaires d\'épiceries. Pour vous inscrire en tant que commerçant, contactez l\'administration.',
                          style: TextStyle(
                            color: AppTheme.info.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
