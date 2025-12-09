import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/admin_scaffold.dart';
import '../../core/widgets/status_badge.dart';

class DriversScreen extends StatefulWidget {
  const DriversScreen({super.key});

  @override
  State<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends State<DriversScreen> {
  String _selectedFilter = 'الكل';
  final List<String> _filters = ['الكل', 'متصل', 'غير متصل', 'محظور'];

  // Dummy data for demonstration
  List<Map<String, dynamic>> get _drivers => [
    {
      'id': 'DRV-001',
      'name': 'محمد ولد أحمد',
      'phone': '+222 22 34 56 78',
      'operator': 'موريتل',
      'status': 'متصل',
      'rating': 4.8,
      'totalTrips': 145,
      'vehicle': 'تويوتا هايلوكس 2020',
      'plate': 'NKC-1234',
    },
    {
      'id': 'DRV-002',
      'name': 'عبدالله ولد محمود',
      'phone': '+222 33 45 67 89',
      'operator': 'شنقيتل',
      'status': 'متصل',
      'rating': 4.6,
      'totalTrips': 98,
      'vehicle': 'فورد رينجر 2019',
      'plate': 'NKC-5678',
    },
    {
      'id': 'DRV-003',
      'name': 'حسن ولد عمر',
      'phone': '+222 44 56 78 90',
      'operator': 'ماتل',
      'status': 'غير متصل',
      'rating': 4.9,
      'totalTrips': 234,
      'vehicle': 'نيسان نافارا 2021',
      'plate': 'NKC-9012',
    },
  ];

  List<Map<String, dynamic>> get _filteredDrivers {
    if (_selectedFilter == 'الكل') return _drivers;
    return _drivers.where((driver) => driver['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'إدارة السائقين',
      actions: [
        SizedBox(width: AdminSpacing.md),
        ElevatedButton.icon(
          onPressed: () {
            // TODO: Add driver
          },
          icon: const Icon(Icons.add),
          label: const Text('إضافة سائق'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats cards
          Row(
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
                          '${_drivers.length}',
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
                          '${_drivers.where((d) => d['status'] == 'متصل').length}',
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
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Filters
          Row(
            children: [
              Text(
                'تصفية:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(width: AdminSpacing.md),
              ...(_filters.map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: EdgeInsetsDirectional.only(end: AdminSpacing.sm),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                    backgroundColor: AdminAppColors.surfaceLight,
                    selectedColor: AdminAppColors.primaryGreen.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AdminAppColors.primaryGreen
                          : AdminAppColors.textPrimaryLight,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              })),
            ],
          ),

          SizedBox(height: AdminSpacing.lg),

          // Drivers table
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  AdminAppColors.backgroundLight,
                ),
                columns: [
                  DataColumn(
                    label: Text(
                      'الرقم',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
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
                      'المشغل',
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
                      'الرحلات',
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
                rows: _filteredDrivers.map((driver) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          driver['id'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(driver['name'])),
                      DataCell(Text(driver['phone'])),
                      DataCell(
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AdminSpacing.sm,
                            vertical: AdminSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: _getOperatorColor(driver['operator']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AdminSpacing.radiusSm),
                          ),
                          child: Text(
                            driver['operator'],
                            style: TextStyle(
                              color: _getOperatorColor(driver['operator']),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        driver['status'] == 'متصل'
                            ? StatusBadge.online(driver['status'])
                            : StatusBadge.offline(driver['status']),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: AdminAppColors.goldenYellow, size: 16),
                            SizedBox(width: AdminSpacing.xxs),
                            Text(
                              driver['rating'].toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          driver['totalTrips'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
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
                            IconButton(
                              icon: const Icon(Icons.block),
                              onPressed: () {
                                _showBlockDialog(context, driver['name']);
                              },
                              tooltip: 'حظر السائق',
                              color: AdminAppColors.errorLight,
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

          SizedBox(height: AdminSpacing.md),

          // Summary
          Text(
            'عرض ${_filteredDrivers.length} من أصل ${_drivers.length} سائق',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AdminAppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _getOperatorColor(String operator) {
    switch (operator) {
      case 'موريتل':
        return AdminAppColors.primaryGreen;
      case 'شنقيتل':
        return AdminAppColors.activeBlue;
      case 'ماتل':
        return AdminAppColors.accentRed;
      default:
        return AdminAppColors.textSecondaryLight;
    }
  }

  void _showDriverDetails(BuildContext context, Map<String, dynamic> driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تفاصيل السائق ${driver['name']}'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('الرقم:', driver['id']),
              _buildDetailRow('الهاتف:', driver['phone']),
              _buildDetailRow('المشغل:', driver['operator']),
              _buildDetailRow('الحالة:', driver['status']),
              _buildDetailRow('التقييم:', driver['rating'].toString()),
              _buildDetailRow('عدد الرحلات:', driver['totalTrips'].toString()),
              _buildDetailRow('المركبة:', driver['vehicle']),
              _buildDetailRow('لوحة الأرقام:', driver['plate']),
            ],
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
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context, String driverName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحظر'),
        content: Text('هل أنت متأكد من حظر السائق $driverName؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Block driver
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم حظر السائق $driverName'),
                  backgroundColor: AdminAppColors.successLight,
                ),
              );
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
}
