import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/battery_optimization_manager.dart';
import '../../services/fcm_token_manager.dart';
import '../../services/missed_notification_recovery.dart';
import '../../services/notification_health_monitor.dart';
import '../../services/notification_retry_service.dart';

/// Notification health dashboard screen.
///
/// Displays comprehensive diagnostic information about the notification system:
/// - Health score (0-100)
/// - Individual system checks
/// - Recommendations
/// - Quick fix actions
/// - Statistics
class NotificationHealthScreen extends ConsumerStatefulWidget {
  const NotificationHealthScreen({super.key});

  @override
  ConsumerState<NotificationHealthScreen> createState() =>
      _NotificationHealthScreenState();
}

class _NotificationHealthScreenState
    extends ConsumerState<NotificationHealthScreen> {
  bool _isLoading = true;
  NotificationHealthReport? _report;
  RetryStatistics? _retryStats;
  RecoveryStatistics? _recoveryStats;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    setState(() => _isLoading = true);

    try {
      final monitor = NotificationHealthMonitor();
      final report = await monitor.checkHealth();
      final retryStats = NotificationRetryService().getStatistics();
      final recoveryStats = await MissedNotificationRecovery().getStatistics();

      setState(() {
        _report = report;
        _retryStats = retryStats;
        _recoveryStats = recoveryStats;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading health data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _runAutoRepair() async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('🔧 Running auto-repair...')),
    );

    final monitor = NotificationHealthMonitor();
    final success = await monitor.autoRepair();

    if (success) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('✅ Auto-repair completed'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadHealthData();
    } else {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('⚠️ Auto-repair failed'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _requestBatteryExemption() async {
    final scaffold = ScaffoldMessenger.of(context);
    final manager = BatteryOptimizationManager();
    final success = await manager.requestExemption();

    if (success) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('✅ Battery optimization exemption granted'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadHealthData();
    } else {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please disable battery optimization in settings'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _refreshToken() async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      const SnackBar(content: Text('🔄 Refreshing FCM token...')),
    );

    await FcmTokenManager().forceRefresh();

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('✅ FCM token refreshed'),
        backgroundColor: Colors.green,
      ),
    );
    await _loadHealthData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صحة نظام الإشعارات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealthData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHealthData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHealthScoreCard(),
                  const SizedBox(height: 16),
                  _buildChecksCard(),
                  const SizedBox(height: 16),
                  _buildRecommendationsCard(),
                  const SizedBox(height: 16),
                  _buildStatisticsCard(),
                  const SizedBox(height: 16),
                  _buildActionsCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildHealthScoreCard() {
    if (_report == null) return const SizedBox.shrink();

    final score = _report!.score;
    final color = score >= 80
        ? Colors.green
        : score >= 60
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _report!.status,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey[300],
                    color: color,
                  ),
                  Center(
                    child: Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'درجة الصحة من 100',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecksCard() {
    if (_report == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'فحوصات النظام',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildCheckItem('FCM Token', _report!.checks['fcm_token'] ?? false),
            _buildCheckItem(
              'استثناء البطارية',
              _report!.checks['battery_exempt'] ?? false,
            ),
            _buildCheckItem(
              'إذن الإشعارات',
              _report!.checks['notification_permission'] ?? false,
            ),
            _buildCheckItem(
              'تجاوز وضع عدم الإزعاج',
              _report!.checks['dnd_bypass'] ?? false,
            ),
            _buildCheckItem(
              'إذن التنبيهات الدقيقة',
              _report!.checks['exact_alarm'] ?? false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard() {
    if (_report == null || _report!.recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توصيات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...(_report!.recommendations.map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 18)),
                      Expanded(child: Text(rec)),
                    ],
                  ),
                ))),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصائيات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (_retryStats != null) ...[
              _buildStatItem(
                  'قائمة إعادة المحاولة', '${_retryStats!.queueSize}'),
              _buildStatItem(
                'إعادة محاولات حديثة',
                '${_retryStats!.recentRetries}',
              ),
              _buildStatItem(
                'مؤقتات نشطة',
                '${_retryStats!.activeTimers}',
              ),
            ],
            if (_recoveryStats != null) ...[
              _buildStatItem(
                'إشعارات تم استردادها',
                '${_recoveryStats!.recoveredCount}',
              ),
              _buildStatItem(
                'آخر فحص',
                _recoveryStats!.lastCheckFormatted,
              ),
              _buildStatItem(
                'حالة الاسترداد',
                _recoveryStats!.isActive ? '🟢 نشط' : '🔴 غير نشط',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'إجراءات سريعة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ElevatedButton.icon(
              onPressed: _runAutoRepair,
              icon: const Icon(Icons.build),
              label: const Text('تشغيل الإصلاح التلقائي'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _requestBatteryExemption,
              icon: const Icon(Icons.battery_charging_full),
              label: const Text('طلب استثناء البطارية'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _refreshToken,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث FCM Token'),
            ),
          ],
        ),
      ),
    );
  }
}
