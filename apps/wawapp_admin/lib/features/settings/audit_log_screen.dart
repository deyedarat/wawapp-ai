/// Audit Log Screen
/// Displays all admin actions for accountability and governance
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../services/audit_log_service.dart';

/// Provider for audit log service
final auditLogServiceProvider = Provider<AuditLogService>((ref) {
  return AuditLogService();
});

/// Provider for audit log stream with category filter
final auditLogStreamProvider = StreamProvider.family<List<AuditLogEntry>, String?>((ref, category) {
  final service = ref.watch(auditLogServiceProvider);
  return service.getAuditLogStream(categoryFilter: category, limit: 200);
});

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _selectedCategory;

  final Map<String, String> _categoryFilters = {
    'الكل': '',
    'السائقون': 'driver',
    'الطلبات': 'order',
    'العملاء': 'client',
    'المالية': 'finance',
    'الإعدادات': 'settings',
    'المصادقة': 'auth',
  };

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogStreamProvider(_selectedCategory));

    return AdminScaffold(
      title: 'سجل العمليات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category filters
          Row(
            children: [
              Text('تصفية:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AdminSpacing.md),
              Expanded(
                child: Wrap(
                  spacing: AdminSpacing.sm,
                  runSpacing: AdminSpacing.sm,
                  children: _categoryFilters.entries.map((entry) {
                    final isSelected = (_selectedCategory ?? '') == entry.value;
                    return FilterChip(
                      label: Text(entry.key),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = entry.value.isEmpty ? null : entry.value;
                        });
                      },
                      backgroundColor: AdminAppColors.surfaceLight,
                      selectedColor: AdminAppColors.primaryGreen.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? AdminAppColors.primaryGreen : AdminAppColors.textPrimaryLight,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: AdminSpacing.lg),

          // Logs list
          logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('خطأ في تحميل السجل: $error'),
                ],
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: AdminAppColors.textSecondaryLight),
                      const SizedBox(height: 16),
                      Text('لا توجد عمليات مسجلة', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                );
              }

              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return _buildLogTile(context, log);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(BuildContext context, AuditLogEntry log) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AdminSpacing.sm),
        decoration: BoxDecoration(
          color: _getCategoryColor(log.category).withOpacity(0.1),
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        ),
        child: Icon(_getCategoryIcon(log.category), color: _getCategoryColor(log.category), size: 20),
      ),
      title: Text(log.actionLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بواسطة: ${log.adminEmail}', style: Theme.of(context).textTheme.bodySmall),
          if (log.targetId != null)
            Text(
              'الهدف: ${log.targetType ?? ''} ${log.targetId!.length > 8 ? log.targetId!.substring(0, 8) : log.targetId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminAppColors.textSecondaryLight),
            ),
        ],
      ),
      trailing: Text(
        _formatDate(log.createdAt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AdminAppColors.textSecondaryLight),
      ),
      isThreeLine: log.targetId != null,
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'driver':
        return AdminAppColors.primaryGreen;
      case 'order':
        return AdminAppColors.activeBlue;
      case 'client':
        return AdminAppColors.goldenYellow;
      case 'finance':
        return AdminAppColors.successLight;
      case 'settings':
        return AdminAppColors.textSecondaryLight;
      case 'auth':
        return AdminAppColors.infoLight;
      default:
        return AdminAppColors.textSecondaryLight;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'driver':
        return Icons.drive_eta;
      case 'order':
        return Icons.local_shipping;
      case 'client':
        return Icons.people;
      case 'finance':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'auth':
        return Icons.security;
      default:
        return Icons.history;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return DateFormat('yyyy-MM-dd HH:mm', 'en').format(date);
  }
}
