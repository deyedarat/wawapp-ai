import 'package:core_shared/core_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/utils/responsive_helper.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';

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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('إضافة سائق قريباً')),
            );
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
                                const Icon(
                                  Icons.drive_eta,
                                  color: AdminAppColors.primaryGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'إجمالي السائقين',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
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
                                const Icon(
                                  Icons.check_circle,
                                  color: AdminAppColors.onlineGreen,
                                  size: 24,
                                ),
                                const SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'متصلون الآن',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
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
                                const Icon(
                                  Icons.verified,
                                  color: AdminAppColors.activeBlue,
                                  size: 24,
                                ),
                                const SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'موثّقون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
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
                                const Icon(
                                  Icons.block,
                                  color: AdminAppColors.errorLight,
                                  size: 24,
                                ),
                                const SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'محظورون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
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
              Text(
                'تصفية:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
                        const Icon(
                          Icons.people_outline,
                          size: 64,
                          color: AdminAppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'لا يوجد سائقون',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
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
                            child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AdminAppColors.backgroundLight,
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    'الاسم',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الهاتف',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الحالة',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'التقييم',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'إجمالي الرحلات',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'موثّق',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'تاريخ التسجيل',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'الإجراءات',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ),
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
                                            const StatusBadge(
                                              label: 'متصل',
                                              color: AdminAppColors.onlineGreen,
                                            )
                                          else
                                            const StatusBadge(
                                              label: 'غير متصل',
                                              color: AdminAppColors.textSecondaryLight,
                                            ),
                                          if (isBlocked) ...[
                                            const SizedBox(width: AdminSpacing.xs),
                                            const StatusBadge(
                                              label: 'محظور',
                                              color: AdminAppColors.errorLight,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            size: 16,
                                            color: AdminAppColors.goldenYellow,
                                          ),
                                          const SizedBox(width: AdminSpacing.xxs),
                                          Text(
                                            driver.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${driver.totalTrips}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      driver.isVerified
                                          ? const Icon(
                                              Icons.verified,
                                              color: AdminAppColors.successLight,
                                              size: 20,
                                            )
                                          : const Icon(
                                              Icons.cancel,
                                              color: AdminAppColors.textSecondaryLight,
                                              size: 20,
                                            ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatDate(driver.createdAt),
                                        style: const TextStyle(fontSize: 12),
                                      ),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AdminAppColors.textSecondaryLight,
                          ),
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
      builder: (context) => AlertDialog(
        title: Text('تفاصيل السائق: ${driver.name}'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('المعرف:', driver.id),
                _buildDetailRow('الاسم:', driver.name),
                _buildDetailRow('الهاتف:', driver.phone),
                _buildDetailRow('نوع المركبة:', driver.vehicleType ?? '-'),
                _buildDetailRow('الحالة:', driver.isOnline ? 'متصل' : 'غير متصل'),
                _buildDetailRow('موثّق:', driver.isVerified ? 'نعم' : 'لا'),
                _buildDetailRow(
                  'محظور:',
                  driverData['isBlocked'] == true ? 'نعم' : 'لا',
                ),
                _buildDetailRow('التقييم:', driver.rating.toStringAsFixed(1)),
                _buildDetailRow('إجمالي الرحلات:', '${driver.totalTrips}'),
                _buildDetailRow('تاريخ التسجيل:', _formatDate(driver.createdAt)),
                _buildDetailRow('آخر تحديث:', _formatDate(driver.updatedAt)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AdminAppColors.textSecondaryLight,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(value),
          ),
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
              decoration: const InputDecoration(
                labelText: 'سبب الحظر (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('جارٍ حظر السائق...')),
              );

              final service = ref.read(adminDriversServiceProvider);
              final success = await service.blockDriver(
                driver.id,
                reason: reasonController.text.isNotEmpty ? reasonController.text : null,
              );

              if (mounted) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم حظر السائق \${driver.name}' : 'فشل حظر السائق',
                    ),
                    backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.errorLight,
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.unblockDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text(success ? 'تم إلغاء حظر ${driver.name}' : 'فشل إلغاء الحظر'),
                  backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                ));
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.verifyDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text(success ? 'تم توثيق ${driver.name}' : 'فشل التوثيق'),
                  backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                ));
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final messenger = ScaffoldMessenger.of(context);
              final service = ref.read(adminDriversServiceProvider);
              final success = await service.unverifyDriver(driver.id);
              if (mounted) {
                messenger.showSnackBar(SnackBar(
                  content: Text(success ? 'تم إلغاء توثيق ${driver.name}' : 'فشل إلغاء التوثيق'),
                  backgroundColor: success ? AdminAppColors.warningLight : AdminAppColors.errorLight,
                ));
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
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('أدخل مبلغاً صحيحاً')),
                );
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
                messenger.showSnackBar(SnackBar(
                  content: Text(success ? 'تم إضافة $amount MRU لـ ${driver.name}' : 'فشل إضافة الرصيد'),
                  backgroundColor: success ? AdminAppColors.successLight : AdminAppColors.errorLight,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminAppColors.primaryGreen),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}
