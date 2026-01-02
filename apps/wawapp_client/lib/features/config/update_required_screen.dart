import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Screen displayed when app requires an update
/// Shown when forceUpdate is true or app version < minClientVersion
class UpdateRequiredScreen extends StatelessWidget {
  final String currentVersion;
  final String requiredVersion;
  final String? message;
  final bool isForced;

  const UpdateRequiredScreen({
    super.key,
    required this.currentVersion,
    required this.requiredVersion,
    this.message,
    this.isForced = true,
  });

  Future<void> _openStore(BuildContext context) async {
    Uri? storeUrl;

    if (Platform.isAndroid) {
      // Replace with your actual package name
      storeUrl = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.wawapp.client',
      );
    } else if (Platform.isIOS) {
      // Replace with your actual App Store ID
      storeUrl = Uri.parse(
        'https://apps.apple.com/app/idYOUR_APP_ID',
      );
    }

    if (storeUrl != null) {
      try {
        if (await canLaunchUrl(storeUrl)) {
          await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تعذر فتح المتجر')),
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
                // Update icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'تحديث مطلوب',
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
                  message ??
                      'يرجى تحديث التطبيق للحصول على أحدث الميزات والتحسينات',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Version info card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildVersionRow(
                        'الإصدار الحالي',
                        currentVersion,
                        Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white24),
                      const SizedBox(height: 12),
                      _buildVersionRow(
                        'الإصدار المطلوب',
                        requiredVersion,
                        Colors.green,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Update button
                ElevatedButton.icon(
                  onPressed: () => _openStore(context),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'تحديث الآن',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                // Skip button (only if not forced)
                if (!isForced) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'ليس الآن',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],

                // Warning for forced updates
                if (isForced) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.warning_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'هذا التحديث إلزامي للمتابعة',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildVersionRow(String label, String version, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
            ),
          ),
          child: Text(
            version,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
