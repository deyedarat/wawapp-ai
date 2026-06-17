import 'package:core_shared/core_shared.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/admin_drivers_service.dart';
import '../../services/audit_log_service.dart';

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  bool? _onlineFilter;
  final ScrollController _tableHorizontalController = ScrollController();

  @override
  void dispose() {
    _tableHorizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(driversStreamProvider(_onlineFilter));
    final statsAsync = ref.watch(driverStatsProvider);

    return AdminScaffold(
      title: 'إدارة السائقين',
      actions: [
        const SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            _showAddDriverDialog(context);
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة سائق'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          statsAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('خطأ في تحميل الإحصائيات: $error'),
            data: (stats) {
              final totalDrivers = stats['total'] ?? 0;
              final onlineDrivers = stats['online'] ?? 0;
              final verifiedDrivers = stats['verified'] ?? 0;
              final blockedDrivers = stats['blocked'] ?? 0;

              return Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.drive_eta, color: AdminAppColors.primaryGreen, size: 24),
                                const SizedBox(width: AdminSpacing.sm),
                                Text('إجمالي السائقين', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$totalDrivers',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AdminAppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: AdminAppColors.onlineGreen, size: 24),
                                const SizedBox(width: AdminSpacing.sm),
                                Text('متصلون الآن', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$onlineDrivers',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AdminAppColors.onlineGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified, color: AdminAppColors.activeBlue, size: 24),
                                const SizedBox(width: AdminSpacing.sm),
                                Text('موثّقون', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$verifiedDrivers',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AdminAppColors.activeBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.block, color: AdminAppColors.errorLight, size: 24),
                                const SizedBox(width: AdminSpacing.sm),
                                Text('محظورون', style: Theme.of(context).textTheme.titleMedium),
                              ],
                            ),
                            const SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$blockedDrivers',
                              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                color: AdminAppColors.errorLight,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: AdminSpacing.xl),

          // Filters
          Row(
            children: [
              Text('تصفية:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(width: AdminSpacing.md),
              FilterChip(
                label: const Text('الكل'),
                selected: _onlineFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _onlineFilter = null;
                  });
                },
              ),
              const SizedBox(width: AdminSpacing.sm),
              FilterChip(
                label: const Text('متصلون'),
                selected: _onlineFilter == true,
                onSelected: (selected) {
                  setState(() {
                    _onlineFilter = true;
                  });
                },
              ),
              const SizedBox(width: AdminSpacing.sm),
              FilterChip(
                label: const Text('غير متصلين'),
                selected: _onlineFilter == false,
                onSelected: (selected) {
                  setState(() {
                    _onlineFilter = false;
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: AdminSpacing.lg),

          // Drivers table - Using AsyncValue instead of StreamBuilder
          SizedBox(
            height: ResponsiveHelper.getTableHeight(context),
            child: driversAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('خطأ في تحميل السائقين: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(driversStreamProvider(_onlineFilter));
                      },
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
              data: (drivers) {
                if (drivers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: AdminAppColors.textSecondaryLight),
                        const SizedBox(height: 16),
                        Text('لا يوجد سائقون', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Card(
                        child: Scrollbar(
                          controller: _tableHorizontalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _tableHorizontalController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 1200),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(AdminAppColors.backgroundLight),
                                columns: [
                                  DataColumn(label: Text('الاسم', style: Theme.of(context).textTheme.titleSmall)),
                                  DataColumn(label: Text('الهاتف', style: Theme.of(context).textTheme.titleSmall)),
                                  DataColumn(label: Text('الحالة', style: Theme.of(context).textTheme.titleSmall)),
                                  DataColumn(label: Text('التقييم', style: Theme.of(context).textTheme.titleSmall)),
                                  DataColumn(
                                    label: Text('إجمالي الرحلات', style: Theme.of(context).textTheme.titleSmall),
                                  ),
                                  DataColumn(label: Text('موثّق', style: Theme.of(context).textTheme.titleSmall)),
                                  DataColumn(
                                    label: Text('تاريخ التسجيل', style: Theme.of(context).textTheme.titleSmall),
                                  ),
                                  DataColumn(label: Text('الإجراءات', style: Theme.of(context).textTheme.titleSmall)),
                                ],
                                rows: drivers.map((driver) {
                                  final isBlocked = driver.toJson()['isBlocked'] == true;

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          driver.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isBlocked ? AdminAppColors.textSecondaryLight : null,
                                          ),
                                        ),
                                      ),
                                      DataCell(Text(driver.phone)),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (driver.isOnline)
                                              const StatusBadge(label: 'متصل', color: AdminAppColors.onlineGreen)
                                            else
                                              const StatusBadge(
                                                label: 'غير متصل',
                                                color: AdminAppColors.textSecondaryLight,
                                              ),
                                            if (isBlocked) ...[
                                              const SizedBox(width: AdminSpacing.xs),
                                              const StatusBadge(label: 'محظور', color: AdminAppColors.errorLight),
                                            ],
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star, size: 16, color: AdminAppColors.goldenYellow),
                                            const SizedBox(width: AdminSpacing.xxs),
                                            Text(
                                              driver.rating.toStringAsFixed(1),
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          '${driver.totalTrips}',
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      DataCell(
                                        driver.isVerified
                                            ? const Icon(Icons.verified, color: AdminAppColors.successLight, size: 20)
                                            : const Icon(
                                                Icons.cancel,
                                                color: AdminAppColors.textSecondaryLight,
                                                size: 20,
                                              ),
                                      ),
                                      DataCell(
                                        Text(_formatDate(driver.createdAt), style: const TextStyle(fontSize: 12)),
                                      ),
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.visibility),
                                              onPressed: () {
                                                _showDriverDetails(context, driver);
                                              },
                                              tooltip: 'عرض التفاصيل',
                                              color: AdminAppColors.infoLight,
                                            ),
                                            if (!driver.isVerified)
                                              IconButton(
                                                icon: const Icon(Icons.verified),
                                                onPressed: () => _showVerifyDialog(context, driver),
                                                tooltip: 'توثيق السائق',
                                                color: AdminAppColors.successLight,
                                              )
                                            else
                                              IconButton(
                                                icon: const Icon(Icons.remove_circle_outline),
                                                onPressed: () => _showUnverifyDialog(context, driver),
                                                tooltip: 'إلغاء التوثيق',
                                                color: AdminAppColors.warningLight,
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.account_balance_wallet),
                                              onPressed: () => _showAddBalanceDialog(context, driver),
                                              tooltip: 'إضافة رصيد',
                                              color: AdminAppColors.primaryGreen,
                                            ),
                                            if (!isBlocked)
                                              IconButton(
                                                icon: const Icon(Icons.block),
                                                onPressed: () {
                                                  _showBlockDialog(context, driver);
                                                },
                                                tooltip: 'حظر السائق',
                                                color: AdminAppColors.errorLight,
                                              )
                                            else
                                              IconButton(
                                                icon: const Icon(Icons.check_circle),
                                                onPressed: () {
                                                  _showUnblockDialog(context, driver);
                                                },
                                                tooltip: 'إلغاء الحظر',
                                                color: AdminAppColors.successLight,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    Text(
                      'عرض ${drivers.length} سائق',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminAppColors.textSecondaryLight),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final formatter = DateFormat('yyyy-MM-dd', 'en');
    return formatter.format(date);
  }

  void _showDriverDetails(BuildContext context, DriverProfile driver) {
    final driverData = driver.toJson();

    showDialog(
      context: context,
      builder: (context) => _DriverDetailsDialog(
        driver: driver,
        driverData: driverData,
        onResetDispatchState: () async {
          final service = ref.read(adminDriversServiceProvider);
          final success = await service.resetDriverDispatchState(driver.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(success ? 'تم تحرير السائق بنجاح' : 'فشل تحرير السائق'),
                backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
              ),
            );
          }
        },
        adminDriversService: ref.read(adminDriversServiceProvider),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AdminAppColors.textSecondaryLight),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, DriverProfile driver) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحظر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل أنت متأكد من حظر السائق \${driver.name}؟'),
            const SizedBox(height: AdminSpacing.md),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'سبب الحظر (اختياري)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لا')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(content: Text('جارٍ حظر السائق...')));

              final service = ref.read(adminDriversServiceProvider);
              final success = await service.blockDriver(
                driver.id,
                reason: reasonController.text.isNotEmpty ? reasonController.text : null,
              );

              if (mounted) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم حظر السائق \${driver.name}' : 'فشل حظر السائق'),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.errorLight),
            child: const Text('نعم، حظر'),
          ),
        ],
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, DriverProfile driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء الحظر'),
        content: Text('هل أنت متأكد من إلغاء حظر السائق ${driver.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('لا')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.unblockDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم إلغاء حظر ${driver.name}' : 'فشل إلغاء الحظر'),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.successLight),
            child: const Text('نعم، إلغاء الحظر'),
          ),
        ],
      ),
    );
  }

  void _showVerifyDialog(BuildContext context, DriverProfile driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('توثيق السائق'),
        content: Text('هل تريد توثيق السائق ${driver.name}؟\nسيتمكن من رؤية الطلبات وقبولها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.verifyDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم توثيق ${driver.name}' : 'فشل التوثيق'),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.successLight),
            child: const Text('توثيق'),
          ),
        ],
      ),
    );
  }

  void _showUnverifyDialog(BuildContext context, DriverProfile driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء التوثيق'),
        content: Text('هل تريد إلغاء توثيق السائق ${driver.name}؟\nلن يتمكن من رؤية الطلبات أو قبولها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.unverifyDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم إلغاء توثيق ${driver.name}' : 'فشل إلغاء التوثيق'),
                    backgroundColor: success ? AdminAppColors.warningLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.warningLight),
            child: const Text('إلغاء التوثيق'),
          ),
        ],
      ),
    );
  }

  void _showAddBalanceDialog(BuildContext context, DriverProfile driver) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة رصيد لـ ${driver.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (MRU)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: AdminSpacing.md),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
                return;
              }
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.addBalance(
                driver.id,
                amount,
                note: noteController.text.isNotEmpty ? noteController.text : null,
              );
              if (mounted) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'تم إضافة $amount MRU لـ ${driver.name}' : 'فشل إضافة الرصيد'),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.primaryGreen),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _showAddDriverDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('إضافة سائق جديد'),
            content: SizedBox(
              width: 420,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم الكامل',
                        hintText: 'مثال: محمد ولد أحمد',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        hintText: '+222XXXXXXXX',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty ? 'رقم الهاتف مطلوب' : null,
                    ),
                    const SizedBox(height: AdminSpacing.md),
                    TextFormField(
                      controller: vehicleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نوع المركبة (اختياري)',
                        hintText: 'مثال: دراجة نارية',
                        prefixIcon: Icon(Icons.two_wheeler),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminAppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);
                        try {
                          final docRef = await FirebaseFirestore.instance.collection('drivers').add({
                            'name': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'vehicleType': vehicleCtrl.text.trim(),
                            'isOnline': false,
                            'isVerified': false,
                            'isBlocked': false,
                            'rating': 5.0,
                            'totalTrips': 0,
                            'createdAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                          // Audit log
                          await AuditLogService().log(
                            action: 'driver_added',
                            category: 'driver',
                            targetId: docRef.id,
                            targetType: 'driver',
                            details: {'name': nameCtrl.text.trim(), 'phone': phoneCtrl.text.trim()},
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة السائق بنجاح'),
                                backgroundColor: AdminAppColors.successLight,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('إضافة'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dialog widget that shows driver details including dispatch eligibility
class _DriverDetailsDialog extends StatefulWidget {
  final DriverProfile driver;
  final Map<String, dynamic> driverData;
  final Future<void> Function() onResetDispatchState;
  final AdminDriversService adminDriversService;

  const _DriverDetailsDialog({
    required this.driver,
    required this.driverData,
    required this.onResetDispatchState,
    required this.adminDriversService,
  });

  @override
  State<_DriverDetailsDialog> createState() => _DriverDetailsDialogState();
}

class _DriverDetailsDialogState extends State<_DriverDetailsDialog> {
  Map<String, dynamic>? _eligibility;
  bool _loading = true;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _loadEligibility();
  }

  Future<void> _loadEligibility() async {
    final result = await widget.adminDriversService.getDriverEligibilityDiagnosis(widget.driver.id);
    if (mounted) {
      setState(() {
        _eligibility = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('تفاصيل السائق: ${widget.driver.name}'),
      content: SizedBox(
        width: 550,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic info
              _buildDetailRow('المعرف:', widget.driver.id),
              _buildDetailRow('الاسم:', widget.driver.name),
              _buildDetailRow('الهاتف:', widget.driver.phone),
              _buildDetailRow('نوع المركبة:', widget.driver.vehicleType ?? '-'),
              _buildDetailRow('الحالة:', widget.driver.isOnline ? 'متصل' : 'غير متصل'),
              _buildDetailRow('موثّق:', widget.driver.isVerified ? 'نعم' : 'لا'),
              _buildDetailRow('محظور:', widget.driverData['isBlocked'] == true ? 'نعم' : 'لا'),
              _buildDetailRow('التقييم:', widget.driver.rating.toStringAsFixed(1)),
              _buildDetailRow('إجمالي الرحلات:', '${widget.driver.totalTrips}'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // Eligibility section
              Text(
                'حالة الأهلية للطلبات',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_eligibility != null) ...[
                // Status indicator
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _eligibility!['eligible'] == true
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _eligibility!['eligible'] == true ? Colors.green : Colors.red, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _eligibility!['eligible'] == true ? Icons.check_circle : Icons.error,
                        color: _eligibility!['eligible'] == true ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _eligibility!['eligible'] == true ? 'مؤهل لاستقبال الطلبات' : 'محجوب عن الطلبات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _eligibility!['eligible'] == true ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),

                // Reasons list
                if (_eligibility!['reasons'] != null && (_eligibility!['reasons'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('أسباب الحجب:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ...(_eligibility!['reasons'] as List).map(
                    (reason) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Expanded(child: Text(reason.toString(), style: const TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                ],

                // Location age
                if (_eligibility!['locationAge'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildDetailRow('عمر الموقع:', '${_eligibility!['locationAge']} دقيقة'),
                  ),

                // Dispatch state details
                if (_eligibility!['dispatchState'] != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('حالة الـ Dispatch:', '${_eligibility!['dispatchState']['status'] ?? 'غير محدد'}'),
                  if (_eligibility!['dispatchState']['activeOrderId'] != null)
                    _buildDetailRow('طلب نشط:', '${_eligibility!['dispatchState']['activeOrderId']}'),
                ],

                // Reset button
                if (_eligibility!['eligible'] != true &&
                    _eligibility!['dispatchState'] != null &&
                    (_eligibility!['dispatchState']['activeOrderId'] != null ||
                        _eligibility!['dispatchState']['status'] == 'busy')) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _resetting
                          ? null
                          : () async {
                              setState(() => _resetting = true);
                              await widget.onResetDispatchState();
                              await _loadEligibility();
                              setState(() => _resetting = false);
                            },
                      icon: _resetting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.lock_open),
                      label: Text(_resetting ? 'جارٍ التحرير...' : 'تحرير السائق (إزالة الحجب)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: AdminAppColors.textSecondaryLight),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
