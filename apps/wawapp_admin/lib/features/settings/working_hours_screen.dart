import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';

// ---------- Model ----------
class WorkingHoursConfig {
  final String id;
  final String dayName;
  final int dayIndex; // 0=Sunday ... 6=Saturday
  final bool isWorkingDay;
  final String openTime; // e.g. "08:00"
  final String closeTime; // e.g. "22:00"

  WorkingHoursConfig({
    required this.id,
    required this.dayName,
    required this.dayIndex,
    required this.isWorkingDay,
    required this.openTime,
    required this.closeTime,
  });

  factory WorkingHoursConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WorkingHoursConfig(
      id: doc.id,
      dayName: data['dayName'] ?? '',
      dayIndex: data['dayIndex'] ?? 0,
      isWorkingDay: data['isWorkingDay'] ?? true,
      openTime: data['openTime'] ?? '08:00',
      closeTime: data['closeTime'] ?? '22:00',
    );
  }
}

// ---------- Defaults ----------
final _defaultDays = [
  {
    'dayIndex': 0,
    'dayName': 'الأحد',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '22:00'
  },
  {
    'dayIndex': 1,
    'dayName': 'الاثنين',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '22:00'
  },
  {
    'dayIndex': 2,
    'dayName': 'الثلاثاء',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '22:00'
  },
  {
    'dayIndex': 3,
    'dayName': 'الأربعاء',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '22:00'
  },
  {
    'dayIndex': 4,
    'dayName': 'الخميس',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '22:00'
  },
  {
    'dayIndex': 5,
    'dayName': 'الجمعة',
    'isWorkingDay': false,
    'openTime': '08:00',
    'closeTime': '14:00'
  },
  {
    'dayIndex': 6,
    'dayName': 'السبت',
    'isWorkingDay': true,
    'openTime': '08:00',
    'closeTime': '20:00'
  },
];

// ---------- Provider ----------
final workingHoursProvider = StreamProvider<List<WorkingHoursConfig>>((ref) {
  return FirebaseFirestore.instance
      .collection('working_hours')
      .orderBy('dayIndex')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => WorkingHoursConfig.fromFirestore(d)).toList());
});

// ---------- Screen ----------
class WorkingHoursScreen extends ConsumerStatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  ConsumerState<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends ConsumerState<WorkingHoursScreen> {
  bool _isInitializing = false;

  Future<void> _initializeDefaults() async {
    setState(() => _isInitializing = true);
    final batch = FirebaseFirestore.instance.batch();
    final col = FirebaseFirestore.instance.collection('working_hours');
    for (final day in _defaultDays) {
      final ref = col.doc();
      batch.set(ref, {
        ...day,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    if (mounted) setState(() => _isInitializing = false);
  }

  @override
  Widget build(BuildContext context) {
    final hoursAsync = ref.watch(workingHoursProvider);

    return AdminScaffold(
      title: 'أوقات العمل',
      child: hoursAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (configs) {
          if (configs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 64, color: AdminAppColors.textSecondaryLight),
                  const SizedBox(height: 16),
                  Text('لم يتم تهيئة أوقات العمل بعد',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isInitializing ? null : _initializeDefaults,
                    icon: _isInitializing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.settings_suggest),
                    label: const Text('تهيئة الإعدادات الافتراضية'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Card(
                  color: AdminAppColors.primaryGreen.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(AdminSpacing.md),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AdminAppColors.primaryGreen),
                        const SizedBox(width: AdminSpacing.sm),
                        Expanded(
                          child: Text(
                            'أيام العمل: ${configs.where((c) => c.isWorkingDay).length} من أصل ${configs.length} أيام',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AdminSpacing.lg),

                // Days list
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: configs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _buildDayRow(context, configs[i]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayRow(BuildContext context, WorkingHoursConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.lg, vertical: AdminSpacing.sm),
      child: Row(
        children: [
          // Day name + toggle
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Switch(
                  value: config.isWorkingDay,
                  activeColor: AdminAppColors.primaryGreen,
                  onChanged: (val) =>
                      _updateDay(config.id, {'isWorkingDay': val}),
                ),
                const SizedBox(width: AdminSpacing.xs),
                Expanded(
                  child: Text(
                    config.dayName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: config.isWorkingDay
                              ? null
                              : AdminAppColors.textSecondaryLight,
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AdminSpacing.lg),

          if (config.isWorkingDay) ...[
            // Open time
            _buildTimePicker(
              context,
              label: 'من',
              time: config.openTime,
              onChanged: (t) => _updateDay(config.id, {'openTime': t}),
            ),
            const SizedBox(width: AdminSpacing.md),
            // Close time
            _buildTimePicker(
              context,
              label: 'إلى',
              time: config.closeTime,
              onChanged: (t) => _updateDay(config.id, {'closeTime': t}),
            ),
          ] else
            Text(
              'يوم إجازة',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AdminAppColors.textSecondaryLight,
                  fontStyle: FontStyle.italic),
            ),

          const Spacer(),

          // Hours summary
          if (config.isWorkingDay)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.sm, vertical: AdminSpacing.xxs),
              decoration: BoxDecoration(
                color: AdminAppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
              ),
              child: Text(
                _calcHours(config.openTime, config.closeTime),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AdminAppColors.primaryGreen),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String label,
    required String time,
    required Function(String) onChanged,
  }) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;

    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          final formatted =
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onChanged(formatted);
        }
      },
      borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.md, vertical: AdminSpacing.xs),
        decoration: BoxDecoration(
          border: Border.all(color: AdminAppColors.borderLight),
          borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AdminAppColors.textSecondaryLight)),
            const SizedBox(width: AdminSpacing.xs),
            Text(time,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: AdminSpacing.xs),
            const Icon(Icons.access_time, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDay(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('working_hours')
        .doc(id)
        .update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _calcHours(String open, String close) {
    try {
      final oParts = open.split(':');
      final cParts = close.split(':');
      final oMins = int.parse(oParts[0]) * 60 + int.parse(oParts[1]);
      final cMins = int.parse(cParts[0]) * 60 + int.parse(cParts[1]);
      final diff = cMins - oMins;
      if (diff <= 0) return '—';
      final h = diff ~/ 60;
      final m = diff % 60;
      return m == 0 ? '$h ساعة' : '$h:${m.toString().padLeft(2, '0')} ساعة';
    } catch (_) {
      return '—';
    }
  }
}
