import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen displayed when app is in maintenance mode
/// Blocks all access until maintenance is disabled from backend
class MaintenanceScreen extends StatelessWidget {
  final String? message;
  final String? supportWhatsApp;

  const MaintenanceScreen({
    super.key,
    this.message,
    this.supportWhatsApp,
  });

  Future<void> _launchWhatsApp(BuildContext context) async {
    if (supportWhatsApp == null || supportWhatsApp!.isEmpty) return;

    // Remove any non-numeric characters
    final phoneNumber = supportWhatsApp!.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$phoneNumber');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر فتح WhatsApp')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Maintenance icon
                Icon(
                  Icons.construction_rounded,
                  size: 120,
                  color: Colors.orange.shade400,
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'صيانة مجدولة',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Message
                Text(
                  message ?? 'التطبيق قيد الصيانة حالياً. سنعود قريباً!',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white70,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'نعمل على تحسين خدماتنا',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يرجى المحاولة مرة أخرى بعد قليل',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // WhatsApp support button (if available)
                if (supportWhatsApp != null && supportWhatsApp!.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: () => _launchWhatsApp(context),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('تواصل مع الدعم'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
