import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../providers/admin_auth_providers.dart';

class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends ConsumerState<SecuritySettingsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return AdminScaffold(
      title: 'الأمان والخصوصية',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current user info
            if (currentUser != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AdminSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحساب الحالي',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: AdminSpacing.md),
                      _buildInfoRow(context, Icons.email, 'البريد الإلكتروني',
                          currentUser.email ?? '-'),
                      const Divider(height: AdminSpacing.lg),
                      _buildInfoRow(context, Icons.person, 'معرف المستخدم',
                          currentUser.uid),
                      const Divider(height: AdminSpacing.lg),
                      _buildInfoRow(
                          context,
                          Icons.verified_user,
                          'التحقق من البريد',
                          currentUser.emailVerified
                              ? '✅ مفعّل'
                              : '⚠️ غير مفعّل'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.xl),
            ],

            // Security actions
            Text('إجراءات الأمان',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    // Change password
                    _buildActionTile(
                      context,
                      icon: Icons.lock_reset,
                      title: 'تغيير كلمة المرور',
                      subtitle:
                          'سيتم إرسال رابط إعادة التعيين إلى بريدك الإلكتروني',
                      buttonLabel: 'إرسال رابط',
                      buttonColor: AdminAppColors.activeBlue,
                      onPressed: currentUser?.email == null
                          ? null
                          : () =>
                              _sendPasswordReset(context, currentUser!.email!),
                    ),
                    const Divider(height: AdminSpacing.xl),

                    // Sign out all sessions
                    _buildActionTile(
                      context,
                      icon: Icons.logout,
                      title: 'تسجيل الخروج',
                      subtitle: 'تسجيل الخروج من اللوحة الإدارية',
                      buttonLabel: 'تسجيل خروج',
                      buttonColor: AdminAppColors.errorLight,
                      onPressed: () => _confirmSignOut(context),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AdminSpacing.xl),

            // Security tips
            Text('نصائح الأمان', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AdminSpacing.md),
            Card(
              color: AdminAppColors.primaryGreen.withOpacity(0.03),
              child: Padding(
                padding: const EdgeInsets.all(AdminSpacing.lg),
                child: Column(
                  children: [
                    _buildTip(context, Icons.password,
                        'استخدم كلمة مرور قوية لا تقل عن 8 أحرف تحتوي على أرقام ورموز'),
                    const Divider(height: AdminSpacing.lg),
                    _buildTip(context, Icons.devices,
                        'لا تسجّل الدخول من أجهزة عامة أو غير موثوقة'),
                    const Divider(height: AdminSpacing.lg),
                    _buildTip(context, Icons.security_update_good,
                        'سجّل الخروج دائماً عند الانتهاء من استخدام اللوحة'),
                    const Divider(height: AdminSpacing.lg),
                    _buildTip(context, Icons.warning_amber,
                        'لا تشارك بيانات تسجيل الدخول مع أحد'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AdminAppColors.primaryGreen, size: 20),
        const SizedBox(width: AdminSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AdminAppColors.textSecondaryLight)),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required Color buttonColor,
    required VoidCallback? onPressed,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AdminSpacing.sm),
          decoration: BoxDecoration(
            color: buttonColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
          ),
          child: Icon(icon, color: buttonColor, size: 24),
        ),
        const SizedBox(width: AdminSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              Text(subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AdminAppColors.textSecondaryLight)),
            ],
          ),
        ),
        const SizedBox(width: AdminSpacing.md),
        ElevatedButton(
          onPressed: _isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(buttonLabel),
        ),
      ],
    );
  }

  Widget _buildTip(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AdminAppColors.primaryGreen, size: 20),
        const SizedBox(width: AdminSpacing.md),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }

  Future<void> _sendPasswordReset(BuildContext context, String email) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال رابط إعادة التعيين إلى $email'),
            backgroundColor: AdminAppColors.successLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AdminAppColors.errorLight,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج من لوحة التحكم؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AdminAppColors.errorLight),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) context.go('/login');
            },
            child:
                const Text('تسجيل خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
