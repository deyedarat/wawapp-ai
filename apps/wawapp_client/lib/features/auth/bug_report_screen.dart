import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/log_service.dart';
import 'providers/auth_service_provider.dart';

/// In-app bug report screen.
///
/// Collects last 50 logs, device info, app version, masked phone, and current
/// user UID, then submits a Firestore document to [bug_reports] collection.
class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _descController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _sendReport() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      // ── 1. Collect device + app info ─────────────────────────────────────
      final packageInfo = await PackageInfo.fromPlatform();
      final appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      final packageName = packageInfo.packageName; // e.g. com.wawapp.client

      String deviceInfo = 'Unknown platform';
      try {
        if (Platform.isAndroid) {
          // OS version only (no model/manufacturer without device_info_plus)
          deviceInfo = 'Android OS ${Platform.operatingSystemVersion}';
        } else if (Platform.isIOS) {
          deviceInfo = 'iOS ${Platform.operatingSystemVersion}';
        }
      } catch (_) {
        // Safe fallback
      }

      // ── 2. Collect auth info ──────────────────────────────────────────────
      final currentUser = FirebaseAuth.instance.currentUser;
      final uid = currentUser?.uid ?? '';

      // Masked phone from authService.lastPhoneE164 (never from log buffer)
      final authService = ref.read(phonePinAuthServiceProvider);
      final rawPhone = authService.lastPhoneE164 ?? currentUser?.phoneNumber ?? '';
      final maskedPhone = LogService.instance.maskPhone(rawPhone);

      // ── 3. Collect logs ───────────────────────────────────────────────────
      final logs = LogService.instance.logs;

      // ── 4. Submit to Firestore ────────────────────────────────────────────
      // tzOffset e.g. "+01:00" — helps correlate user-local time with server time
      final tzOffset = DateTime.now().timeZoneOffset;
      final tzSign = tzOffset.isNegative ? '-' : '+';
      final tzHours = tzOffset.inHours.abs().toString().padLeft(2, '0');
      final tzMinutes = (tzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final tzString = '$tzSign$tzHours:$tzMinutes';

      await FirebaseFirestore.instance.collection('bug_reports').add({
        'createdAt': FieldValue.serverTimestamp(),
        'description': _descController.text.trim(),
        'logs': logs,
        'deviceInfo': deviceInfo,
        'appVersion': appVersion,
        'packageName': packageName,
        'uid': uid,
        'maskedPhone': maskedPhone,
        'buildType': 'release',
        'locale': Platform.localeName, // e.g. "ar_MR"
        'tzOffset': tzString, // e.g. "+01:00"
        'clientTimestamp': DateTime.now().toIso8601String(),
      });

      // ── 5. Crashlytics breadcrumb ─────────────────────────────────────────
      FirebaseCrashlytics.instance.log('Manual bug report submitted by uid=$uid');

      // ── 6. Log to LogService buffer ───────────────────────────────────────
      LogService.instance.addLog(
        event: 'bug_report_submitted',
        phone: rawPhone,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال التقرير بنجاح. شكراً لمساعدتنا!',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        // Pop back after short delay so user sees the snackbar
        await Future.delayed(const Duration(milliseconds: 1200));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      // Log failure but never crash
      LogService.instance.addLog(
        event: 'bug_report_failed',
        errorCode: 'send_failed',
        errorMessage: e.runtimeType.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'فشل إرسال التقرير. يرجى التحقق من اتصالك بالإنترنت.',
              textAlign: TextAlign.right,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إرسال تقرير مشكلة'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ساعدنا في تحسين التطبيق بإرسال تفاصيل المشكلة التي واجهتها.',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 24),

                // Optional description field
                TextField(
                  controller: _descController,
                  maxLines: 4,
                  // RTL is inherited from parent Directionality widget
                  decoration: const InputDecoration(
                    labelText: 'وصف المشكلة (اختياري)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    hintText: 'مثال: ظهر خطأ عند إدخال رقم الهاتف...',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ملاحظة: لن يتم إرسال رقم هاتفك الكامل أو رمز التحقق.',
                  style: TextStyle(fontSize: 12, color: Colors.black38),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 32),

                // Send button
                ElevatedButton(
                  onPressed: _isSending ? null : _sendReport,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إرسال التقرير',
                          style: TextStyle(fontSize: 16),
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
