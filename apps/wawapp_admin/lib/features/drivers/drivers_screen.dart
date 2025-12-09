import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_shared/core_shared.dart';
import 'package:intl/intl.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';
import '../../providers/admin_data_providers.dart';
import '../../services/admin_drivers_service.dart';

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  bool? _onlineFilter;

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(
      driversStreamProvider(_onlineFilter).stream,
    );
    final statsAsync = ref.watch(driverStatsProvider);

    return AdminScaffold(
      title: 'إدارة السائقين',
      actions: [
        SizedBox(width: AdminSpacing.md),
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
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.drive_eta,
                                  color: AdminAppColors.primaryGreen,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'إجمالي السائقين',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$totalDrivers',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AdminAppColors.onlineGreen,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'متصلون الآن',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$onlineDrivers',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.onlineGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.verified,
                                  color: AdminAppColors.activeBlue,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'موثّقون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$verifiedDrivers',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
                                    color: AdminAppColors.activeBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AdminSpacing.md),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(AdminSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.block,
                                  color: AdminAppColors.errorLight,
                                  size: 24,
                                ),
                                SizedBox(width: AdminSpacing.sm),
                                Text(
                                  'محظورون',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            SizedBox(height: AdminSpacing.sm),
                            Text(
                              '$blockedDrivers',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(
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

          SizedBox(height: AdminSpacing.xl),

          // Filters
          Row(
            children: [
              Text(
                'تصفية:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(width: AdminSpacing.md),
              FilterChip(
                label: const Text('الكل'),
                selected: _onlineFilter == null,
                onSelected: (selected) {
                  setState(() {
                    _onlineFilter = null;
                  });
                },
              ),
              SizedBox(width: AdminSpacing.sm),
              FilterChip(
                label: const Text('متصلون'),
                selected: _onlineFilter == true,
                onSelected: (selected) {
                  setState(() {
                    _onlineFilter = true;
                  });
                },
              ),
              SizedBox(width: AdminSpacing.sm),
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

          SizedBox(height: AdminSpacing.lg),

          // Drivers table
          Expanded(
            child: StreamBuilder<List<DriverProfile>>(
              stream: driversAsync,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('خطأ في تحميل السائقين: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  );
                }

                final drivers = snapshot.data ?? [];

                if (drivers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
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
                        child: SingleChildScrollView(
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
                                          color: isBlocked
                                              ? AdminAppColors.textSecondaryLight
                                              : null,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(driver.phone)),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (driver.isOnline)
                                            StatusBadge(
                                              label: 'متصل',
                                              color: AdminAppColors.onlineGreen,
                                            )
                                          else
                                            StatusBadge(
                                              label: 'غير متصل',
                                              color: AdminAppColors.textSecondaryLight,
                                            ),
                                          if (isBlocked) ...[
                                            SizedBox(width: AdminSpacing.xs),
                                            StatusBadge(
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
                                          SizedBox(width: AdminSpacing.xxs),
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

                    SizedBox(height: AdminSpacing.md),

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
    final formatter = DateFormat('yyyy-MM-dd', 'ar');
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
                if (driver.updatedAt != null)
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
      padding: EdgeInsets.symmetric(vertical: AdminSpacing.xs),
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
            Text('هل أنت متأكد من حظر السائق ${driver.name}؟'),
            SizedBox(height: AdminSpacing.md),
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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ حظر السائق...')),
              );

              final service = ref.read(adminDriversServiceProvider);
              final success = await service.blockDriver(
                driver.id,
                reason: reasonController.text.isNotEmpty
                    ? reasonController.text
                    : null,
              );

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم حظر السائق ${driver.name}' : 'فشل حظر السائق',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جارٍ إلغاء الحظر...')),
              );

              final service = ref.read(adminDriversServiceProvider);
              final success = await service.unblockDriver(driver.id);

              if (mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'تم إلغاء حظر السائق ${driver.name}' : 'فشل إلغاء الحظر',
                    ),
                    backgroundColor: success
                        ? AdminAppColors.successLight
                        : AdminAppColors.errorLight,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminAppColors.successLight,
            ),
            child: const Text('نعم، إلغاء الحظر'),
          ),
        ],
      ),
    );
  }
}
