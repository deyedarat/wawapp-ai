import 'package:flutter/material.dart';
import 'permission_helper.dart';

/// Diagnostic screen for checking notification permissions status.
///
/// This screen helps drivers and support team diagnose notification issues by:
/// - Showing current status of all critical permissions
/// - Providing buttons to request missing permissions
/// - Offering step-by-step instructions
class PermissionsDiagnosticScreen extends StatefulWidget {
  const PermissionsDiagnosticScreen({super.key});

  @override
  State<PermissionsDiagnosticScreen> createState() => _PermissionsDiagnosticScreenState();
}

class _PermissionsDiagnosticScreenState extends State<PermissionsDiagnosticScreen> {
  Map<String, bool> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() => _isLoading = true);
    final statuses = await PermissionHelper.getDetailedPermissionStatuses();
    setState(() {
      _permissionStatuses = statuses;
      _isLoading = false;
    });
  }

  Future<void> _requestMissingPermissions() async {
    await PermissionHelper.requestMissingPermissions();
    // Wait a bit for user to return from Settings
    await Future.delayed(const Duration(seconds: 2));
    await _loadPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('A-5 #0HF'* 'D%49'1'*'),
          backgroundColor: const Color(0xFF1B5E20),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadPermissions,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Overall Status Card
                    _buildOverallStatusCard(),
                    const SizedBox(height: 24),

                    // Individual Permission Cards
                    _buildPermissionCard(
                      title: '%2'D) BJH/ *HAJ1 'D7'B)',
                      subtitle: 'Battery Optimization Exemption',
                      isGranted: _permissionStatuses['batteryOptimizationDisabled'] ?? false,
                      explanation: '61H1J D6E'F 9ED 'D%49'1'* -*I E9 %:D'B 'D*7(JB',
                    ),
                    const SizedBox(height: 12),

                    _buildPermissionCard(
                      title: '*.7J H69 "9/E 'D%29',"',
                      subtitle: 'Bypass Do Not Disturb',
                      isGranted: _permissionStatuses['canBypassDnd'] ?? false,
                      explanation: 'J3E- DD%49'1'* ('D8GH1 -*I E9 *A9JD H69 "9/E 'D%29',"',
                    ),
                    const SizedBox(height: 12),

                    _buildPermissionCard(
                      title: ',/HD) 'D*F(JG'* 'D/BJB)',
                      subtitle: 'Schedule Exact Alarms',
                      isGranted: _permissionStatuses['canScheduleExactAlarms'] ?? false,
                      explanation: '61H1J D%8G'1 'D%49'1'* (ED! 'D4'4) (Android 12+)',
                    ),
                    const SizedBox(height: 24),

                    // Request Missing Permissions Button
                    if (!_allPermissionsGranted())
                      ElevatedButton.icon(
                        onPressed: _requestMissingPermissions,
                        icon: const Icon(Icons.settings),
                        label: const Text('7D( 'D#0HF'* 'DF'B5)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Instructions Card
                    _buildInstructionsCard(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOverallStatusCard() {
    final allGranted = _allPermissionsGranted();
    final percentage = _getGrantedPercentage();

    return Card(
      color: allGranted ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              allGranted ? Icons.check_circle : Icons.warning,
              size: 48,
              color: allGranted ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 12),
            Text(
              allGranted ? ',EJ9 'D#0HF'* EEFH-) ' : '(96 'D#0HF'* F'B5)  ',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '*E EF- $percentage% EF 'D#0HF'* 'DE7DH()',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation(
                allGranted ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String subtitle,
    required bool isGranted,
    required String explanation,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.cancel,
          color: isGranted ? Colors.green : Colors.red,
          size: 32,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(explanation, style: const TextStyle(fontSize: 13)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  '*9DJE'* %6'AJ)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '" %0' DE *9ED 'D%49'1'* (9/ EF- ,EJ9 'D#0HF'* BE (%9'/) *4:JD 'D*7(JB',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '" #,G2) Samsung: *#C/ EF *97JD "-0A 'D#0HF'* 9F/ 9/E 'D'3*./'E"',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '" #,G2) Xiaomi/Oppo/Vivo: B/ *-*', %9/'/'* %6'AJ) AJ "'D#E'F"',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  bool _allPermissionsGranted() {
    return _permissionStatuses.values.every((granted) => granted == true);
  }

  int _getGrantedPercentage() {
    if (_permissionStatuses.isEmpty) return 0;
    final granted = _permissionStatuses.values.where((v) => v == true).length;
    final total = _permissionStatuses.length;
    return ((granted / total) * 100).round();
  }
}
