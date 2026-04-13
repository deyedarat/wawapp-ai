import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'permission_helper.dart';

/// Key used in SharedPreferences to track if permission setup was completed.
const kPermissionSetupCompleted = 'permission_setup_completed';

/// Screen shown once after first login to guide driver through critical permissions.
class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  Map<String, bool> _statuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Reload statuses when user returns from Settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStatuses();
    }
  }

  Future<void> _loadStatuses() async {
    setState(() => _isLoading = true);
    final s = await PermissionHelper.getDetailedPermissionStatuses();
    if (mounted)
      setState(() {
        _statuses = s;
        _isLoading = false;
      });
  }

  bool get _allGranted =>
      _statuses.values.isNotEmpty && _statuses.values.every((v) => v);

  Future<void> _onContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPermissionSetupCompleted, true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 32),
                      const Icon(Icons.notifications_active,
                          size: 64, color: Color(0xFF1B5E20)),
                      const SizedBox(height: 16),
                      const Text(
                        'إعداد الإشعارات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'لضمان وصول الطلبات إليك بشكل موثوق، نحتاج الأذونات التالية:',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      _tile(
                        'إعفاء من توفير البطارية',
                        'يمنع النظام من إيقاف الإشعارات في الخلفية',
                        Icons.battery_saver,
                        _statuses['batteryOptimizationDisabled'] ?? false,
                        () => PermissionHelper.requestMissingPermissions(),
                      ),
                      _tile(
                        'تجاوز وضع عدم الإزعاج',
                        'يسمح بظهور إشعارات الطلبات حتى في وضع الصامت',
                        Icons.do_not_disturb_off,
                        _statuses['canBypassDnd'] ?? false,
                        () => PermissionHelper.requestMissingPermissions(),
                      ),
                      _tile(
                        'المنبهات الدقيقة',
                        'ضروري لإظهار الإشعارات بملء الشاشة',
                        Icons.alarm,
                        _statuses['canScheduleExactAlarms'] ?? false,
                        () => PermissionHelper.requestMissingPermissions(),
                      ),
                      _tile(
                        'إشعارات ملء الشاشة',
                        'يسمح بإظهار إشعارات الطلبات بملء الشاشة (Android 14+)',
                        Icons.fullscreen,
                        _statuses['canUseFullScreenIntent'] ?? false,
                        () => PermissionHelper.requestMissingPermissions(),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _allGranted
                            ? _onContinue
                            : () async {
                                await PermissionHelper
                                    .requestMissingPermissions();
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                _loadStatuses();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _allGranted
                              ? const Color(0xFF1B5E20)
                              : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _allGranted ? 'متابعة' : 'منح الأذونات',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (!_allGranted) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _onContinue,
                          child: const Text('تخطي (غير مستحسن)',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _tile(String title, String subtitle, IconData icon, bool granted,
      VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading:
            Icon(icon, color: granted ? Colors.green : Colors.orange, size: 28),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: granted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: granted ? null : onTap,
      ),
    );
  }
}
