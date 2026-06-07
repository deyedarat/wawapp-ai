import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';

/// Settings screen for the laundry app.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<LaundryAuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF1B5E20).withOpacity(0.1),
                    child: const Icon(
                      Icons.store,
                      size: 30,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user != null
                              ? Formatters.formatPhoneDisplay(user.phoneNumber)
                              : '',
                          style: TextStyle(color: Colors.grey[600]),
                          textDirection: TextDirection.ltr,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Language Setting
          const Text(
            'اللغة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                RadioListTile<String>(
                  title: const Text('العربية'),
                  subtitle: const Text('Arabic'),
                  value: 'ar',
                  groupValue: localeProvider.locale.languageCode,
                  onChanged: (value) {
                    localeProvider.setLocale(const Locale('ar'));
                  },
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  title: const Text('Français'),
                  subtitle: const Text('French'),
                  value: 'fr',
                  groupValue: localeProvider.locale.languageCode,
                  onChanged: (value) {
                    localeProvider.setLocale(const Locale('fr'));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // App Info
          const Text(
            'حول التطبيق',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('الإصدار'),
                  trailing: const Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('المساعدة'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () {
                    // TODO: Navigate to help
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          ElevatedButton.icon(
            onPressed: () => _handleLogout(context, authProvider),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(
      BuildContext context, LaundryAuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}
